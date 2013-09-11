nconf = require 'nconf'

nconf.argv()
     .env()
     .file({ file: 'config.json' })

authKey = nconf.get("secret_key")
pubnub = require('./pubnub').init
  subscribe_key: 'sub-c-4c15a542-ced1-11e2-b70f-02ee2ddab7fe'
  publish_key: 'pub-c-4268517d-1e7a-4bdd-8037-090a3c76a1f0'
  secret_key: nconf.get("secret_key") # Pass in the secret key so we don't give this out to users
  auth_key: authKey
  origin: 'pam-beta.pubnub.com'

console.log "Granting read-only access to chat channel"
pubnub.grant
  channel: 'chat'
  read: true
  write: false
  callback: (message) ->
    console.log "Successfully made grant request", message
  error: (message) ->
    console.log "[ERROR] On grant request", message

console.log "Granting access for authentication channel"
pubnub.grant
  channel: 'authentication'
  read: false
  write: true
  callback: (message) ->
    # Nothing

console.log "Granting access for self on auth"
pubnub.grant
  channel: 'authentication'
  auth_key: authKey
  read: true
  write: true
  callback: (message) ->
    # Nothing

console.log "Listening for logins and logouts"
pubnub.subscribe
  channel: 'authentication'
  callback: (message) ->
    message = JSON.parse message
    console.log "Got message on auth channel", message

    if message.action is 'login'
      console.log "Logging in #{message.authKey}"
      pubnub.grant
        channel: 'chat'
        read: true
        write: true
        auth_key: message.authKey
        ttl: 1
        callback: () ->
          # Publish back to the user a success
          pubnub.publish
            channel: message.authKey
            message: JSON.stringify
              action: 'login'
              success: true
        error: () ->
          # Publish back to the user a failure
          pubnub.publish
            channel: message.authKey
            message: JSON.stringify
              action: 'login'
              success: false
    else if message.action is 'logout'
      console.log "Logging out #{message.authKey}"
      pubnub.grant
        channel: 'chat'
        read: true
        write: false
        auth_key: message.authKey
        callback: () ->
          # Publish back to the user a success
          pubnub.publish
            channel: message.authKey
            message: JSON.stringify
              action: 'logout'
              success: true
        error: () ->
          # Publish back to the user a failure
          pubnub.publish
            channel: message.authKey
            message: JSON.stringify
              action: 'logout'
              success: false
    else if message.action is 'presence'
      # Allow them access to their own channel
      console.log "Allowing presence for #{message.uuid}"
      pubnub.grant
        channel: message.uuid
        read: true
        write: false
        auth_key: message.uuid
        callback: () ->
          # Nothing
      pubnub.grant
        channel: message.uuid
        read: false
        write: true
        auth_key: authKey
        callback: () ->
          # Nothing
