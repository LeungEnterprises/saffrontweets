# Declare dependencies
express = require 'express'
morgan  = require 'morgan'
request = require 'request'
cheerio = require 'cheerio'
Twit    = require 'twit'

# Answer http requests (depends on hosting provider)
app = express()
app.use morgan('dev')

app.get '*', (req, res) ->
 res.redirect 'https://www.saffronofphilly.com/specials'

app.set 'port', process.env.PORT or 3000
app.set 'ip', process.env.IP or "127.0.0.1"

app.listen app.get('port'), app.get('ip'), ->
  console.log "Server listening on #{app.get 'ip'}:#{app.get 'port'}"

# Get specials, back when they were hardcoded into the HTML
getSpecialsOld = (callback) ->
  specials = []
  request 'http://www.saffronofphilly.com/specials', (error, response, html) ->
    if !error and response.statusCode is 200
      $ = cheerio.load html
      $('.menu > tbody > tr > td:nth-child(1)').each (i, element) ->
        if i % 2 is 0
          index = i / 2
          specials[index] = {}
          specials[index].name = element.children[0].data
        else
          index = (i-1) / 2
          specials[index].description = element.children[0].data
      callback specials

getSpecials = (callback) ->
  specials = []
  request 'http://www.saffronofphilly.com/specials-data/current.json', (error, response, body) ->
    if error
      console.log error
    else
      json = JSON.parse(body);
      request 'http://www.saffronofphilly.com/specials-data/' + json.year + '/' + json.month.toLowerCase() + '.json', (error, response, body) ->
        if error
          console.log error
        else
          specialsObj = JSON.parse(body);
          specialsObj.appetizers.forEach (item) ->
            specials.push item
          specialsObj.entrees.forEach (item) ->
            specials.push item
          callback specials


T = new Twit
  consumer_key: process.env.CONSUMER_KEY
  consumer_secret: process.env.CONSUMER_SECRET
  access_token: process.env.ACCESS_TOKEN
  access_token_secret: process.env.ACCESS_TOKEN_SECRET

postTweet = (specials) ->
  templates = [
    "We have some exciting new specials this month, like {{item.name}}. See more at saffronofphilly.com/specials"
    "Try our mouthwatering {{item.name}}, one of this month's specials. See more at saffronofphilly.com/specials",
    "{{item.name}} is one of this our specials this month. See more at saffronofphilly.com/specials",
    "Visit saffronofphilly.com/specials to see specials like {{item.name}}: {{item.description}}.",
    "Featured special: our mouthwatering {{item.name}}. See more at saffronofphilly.com/specials",
    "We're proud to announce our newest special, the delicious {{item.name}}. More at saffronofphilly.com/specials",
    "{{item.description}} sound good? Try our newest special, {{item.name}}! More at saffronofphilly.com/specials",
    "We have new specials this month, including {{item.name}}: {{item.description}}! saffronofphilly.com/specials"
  ]
  i = Math.floor(Math.random() * specials.length)
  j = Math.floor(Math.random() * templates.length)
  tweet = templates[j]
    .replace(/{{item.name}}/g, specials[i].name)
    # Remove period from end of description
    .replace(
      /{{item.description}}/g,
      specials[i].description.slice(0, -1) or "Authentic indian food "
    )
  T.post 'statuses/update', { status: tweet }, (err, reply) ->
    if (err)
      console.log "Error: #{JSON.stringify(err)}"
      console.log "Tweet:" + tweet
    console.log "Reply: #{JSON.stringify(reply)}"

# On first run, post a new tweet
getSpecials postTweet

# To test, comment out the above lines and uncomment the below line
# getSpecials console.log

getSpecialsAndPost = ->
  try
    getSpecials postTweet
  catch err
    console.log err
    # over 140 chars
    if err.code is 186
      getSpecialsAndPost()

# Post a new tweet every two weeks
setInterval getSpecialsAndPost, 14 * 24 * 60 * 60 * 1000
