# Description
#   Deploy utilities
#
# Dependencies:
#
# Configuration:
#   NODE_ENV=(local|production)
#
# Commands:
#   hubot deploy <env> - Initiates a deploy to <env>
#
# Notes:
#
# Author:
#   benrudolph

config = require('config')
CAPTAIN_URL = config.get 'Deploy.url'

request = require('request')

module.exports = (robot) ->

  robot.respond /deploy ([\w]+)/i, (res) ->
    env = res.match[1]
    codeBranch = 'master'
    user = res.message.user.name
    if env == 'staging'
      codeBranch = 'autostaging'

    data =
      env: env
      code_branch: codeBranch
      deploy_user: user

    request.post(CAPTAIN_URL + '/deploy/', formData: data, (err, response, body) ->
      if err || response.statusCode >= 400
        res.send "Failed to deploy deploy to #{env} on #{codeBranch} by #{user}"
        res.send body
      else
        res.send "Successfully initiated deploy to #{env} on #{codeBranch} by #{user}"
    )



