# Description
#   Runs Fogbugz utilities
#
# Dependencies:
#
# Configuration:
#   NODE_ENV=(local|production)
#
# Commands:
#   hubot fb interrupt - Lists unassigned tickets that are interrupt
#   hubot fb interrupt all - Lists all tickets assigned to interrupt
#   hubot fb neglected - Lists all neglected tickets
#   hubot fb filter <filterId> - Lists cases for that filter id
#
# Notes:
#
# Author:
#   benrudolph

config = require('config')
_ = require('lodash')
request = require('request')
parseString = require('xml2js').parseString

# Fogbugz constants
FB_URL = 'http://manage.dimagi.com'
INTERRUPT_FILTER_ID = 570
NEGLECTED_FILTER_ID = 525
FL_SUPPORT_USER_ID = 103
SUPPORT_AREA_ID = 1269
COMMCAREHQ_PROJECT_ID = 25

module.exports = (robot) ->
  robot.respond /fb filter ([0-9]+)/i, (res) ->
    filterId = res.match[1]
    fbCasesByFilter filterId, (response)->
      out = formatCaseXML response
      if out?
          res.send out
      else
          res.send 'Nothin found.'

  robot.respond /fb neglected/i, (res) ->
    fbCasesByFilter NEGLECTED_FILTER_ID, (response)->
      out = formatCaseXML response
      if out?
          res.send out
      else
          res.send 'Good job! No neglected cases.'

  robot.respond /fb interrupt/i, (res) ->
    fbCasesByFilter INTERRUPT_FILTER_ID, (response)->
      out = formatCaseXML response, (c) ->
        c.sPersonAssignedTo[0].toLowerCase() == 'CommCare HQ Interrupt Team'.toLowerCase()
      if out?
          res.send out
      else
          res.send 'Nice work interrupt! No unassigned cases.'

  robot.respond /fb interrupt all/i, (res) ->
    fbCasesByFilter INTERRUPT_FILTER_ID, (response)->
      out = formatCaseXML response
      if out?
          res.send out
      else
          res.send 'Nice work interrupt! No cases!'

  robot.respond /fb new (.+)/i, (res) ->
    title = res.match[1]
    fbCreateCase title, (response) ->
      bugId = response.case[0].ixBug[0]

      res.send "Game, set, match: #{FB_URL}/default.asp?#{bugId}. Thanks for making CommCareHQ great again."


fbBaseUrl = ->
  apiKey = config.get 'FogBugz.key'

  "#{FB_URL}/api.asp?token=#{apiKey}"

fbCreateCase = (title, callback) ->
  request
    .get(
      {
        url: fbBaseUrl()
        qs: {
          cmd: 'new'
          sTitle: title
          ixPersonAssignedTo: FL_SUPPORT_USER_ID
          ixPriority: 4
          ixProject: COMMCAREHQ_PROJECT_ID
          ixArea: SUPPORT_AREA_ID
          cols: 'ixBug'
        }
      }, (err, response, body) ->
        parseString body, (err, result) ->
          callback result.response
    )

fbCasesByFilter = (filterId, callback) ->
    request
      .get(
        {
          url: fbBaseUrl(),
          qs: {
            cmd: 'setCurrentFilter'
            sFilter: filterId
          }
        }, (err, response, body) ->
          if err
            res.send err
            return

          request
            .get(
              {
                url: fbBaseUrl()
                qs: {
                  cmd: 'search'
                  cols: 'sTitle,sPersonAssignedTo'
                }
              }, (err, response, body) ->
                parseString body, (err, result) ->
                  callback result.response
            )
      )

formatCaseXML = (xmlResponse, filterFn) ->
    cases = xmlResponse.cases[0].case
    if filterFn?
      cases = _.filter cases, filterFn
    out = ''
    _.each cases, (c) ->
      # HTML links are broken, so need to use raw link
      # https://github.com/slackhq/hubot-slack/issues/114
      out += "#{FB_URL}/default.asp?#{c['$'].ixBug}: #{c.sPersonAssignedTo}\n"
    out
