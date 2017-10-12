require 'sinatra'
require 'line/bot'
require 'open-uri'
require 'json'
  
get '/' do
    # list users up and display
    'hello'
end

get '/list/friends' do
    File.open("friend.txt", "r") do |f|
        f.each_line { |line|
            puts line
        }
    end
end

get '/test/push' do
    userId = ENV["LINE_TEST_USER_ID"]
    message = {
        type: 'text',
        text: '†悔い改めて†'
    }
    response = client.push_message(userId, message)
    p "#{response.code} #{response.body}"
end

get '/test/profile' do
    userId = ENV["LINE_TEST_USER_ID"]
    response = client.get_profile(userId)
    case response
    when Net::HTTPSuccess then
        contact = JSON.parse(response.body)
        p contact['displayName']
        p contact['pictureUrl']
        p contact['statusMessage']
    else
        p "#{response.code} #{response.body}"
    end
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  body = request.body.read

  unless client.validate_signature(body, request.env['HTTP_X_LINE_SIGNATURE'])
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        token = '(トークン)'
        droplet_ep = 'http://183.181.14.111/beast/api/?w=' + event.message['text']

        text = ''
        res = open(droplet_ep,
          "Authorization" => "bearer #{token}") do |f| 
            f.each_line do |line|
              text =  JSON.parse(line)['value']
              # puts line
            end 
        end
        message = {
          type: 'text',
          text: text
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    when Line::Bot::Event::Follow
        message = [{
          type: 'text',
          text: '追加してくれてありがとナス！'
        },
        {
          type: 'text',
          text: event['source']['userId']
        }]
        File.open("friend.txt", "a") do |f|
            f.puts event['source']['userId']+"\n"
        end
        client.reply_message(event['replyToken'], message)
    end
  }

  "OK"
end
