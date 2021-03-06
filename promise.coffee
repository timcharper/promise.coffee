# [promise.coffee](http://github.com/CodeCatalyst/promise.coffee) v1.0.5
# Copyright (c) 2012-2103 [CodeCatalyst, LLC](http://www.codecatalyst.com/).
# Open source under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).

nextTick = if process?.nextTick? then process.nextTick else if setImmediate? then setImmediate else ( task ) -> setTimeout( task, 0 )

class CallbackQueue
  constructor: ->
    queuedCallbacks = []
    execute = ->
      (queuedCallbacks.shift())() while queuedCallbacks.length > 0
      return
    @schedule = ( callback ) ->
      queuedCallbacks.push(callback)
      nextTick( execute ) if queuedCallbacks.length is 1
      return

callbackQueue = new CallbackQueue()
enqueue = ( task ) -> callbackQueue.schedule( task )

isFunction = ( value ) -> value and typeof value is 'function'
isObject = ( value ) -> value and typeof value is 'object'

class Consequence
  constructor: ( @onFulfilled, @onRejected ) ->
    @resolver = new Resolver()
    @promise = @resolver.promise
  
  trigger: ( action, value ) ->
    switch action
      when 'fulfill'
        @propagate( value, @onFulfilled, @resolver, @resolver.resolve )
      when 'reject'
        @propagate( value, @onRejected, @resolver, @resolver.reject )
    return
  
  propagate: ( value, callback, resolver, resolverMethod ) ->
    if isFunction( callback )
      enqueue( ->
        try
          resolver.resolve( callback( value ) )
        catch error
          resolver.reject( error )
        return
      )
    else
      resolverMethod.call( resolver, value )
    return

class Resolver
  constructor: ->
    @promise = new Promise( @ )
    @consequences = []
    @completed = false
    @completionAction = null
    @completionValue = null
  
  then: ( onFulfilled, onRejected ) ->
    consequence = new Consequence( onFulfilled, onRejected )
    if @completed
      consequence.trigger( @completionAction, @completionValue )
    else
      @consequences.push( consequence )
    return consequence.promise
  
  resolve: ( value ) ->
    if @completed
      return
    try
      if value is @promise
        throw new TypeError( 'A Promise cannot be resolved with itself.' )
      if ( isObject( value ) or isFunction( value ) ) and isFunction( thenFn = value.then )
        isHandled = false
        try
          self = @
          thenFn.call(
            value
            ( value ) ->
              if not isHandled
                isHandled = true
                self.resolve( value )
              return
            ( error ) ->
              if not isHandled
                isHandled = true
                self.reject( error )
              return
          )
        catch error
          @reject( error ) if not isHandled
      else
        @complete( 'fulfill', value )
    catch error
      @reject( error )
    return
  
  reject: ( error ) ->
    if @completed
      return
    @complete( 'reject', error )
    return
  
  complete: ( action, value ) ->
    @completionAction = action
    @completionValue = value
    @completed = true
    for consequence in @consequences
      consequence.trigger( @completionAction, @completionValue )
    @consequences = null
    return

class Promise
  constructor: ( resolver ) ->
    @then = ( onFulfilled, onRejected ) -> resolver.then( onFulfilled, onRejected )

class Deferred
  constructor: ->
    resolver = new Resolver()
    
    @promise = resolver.promise
    @resolve = ( value ) -> resolver.resolve( value )
    @reject = ( error ) -> resolver.reject( error )

target = exports ? window
target.Deferred = Deferred
target.defer = -> new Deferred()