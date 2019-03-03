module Lita
  module Handlers
    class Rezlog < Handler
      # insert handler code here
     on :shut_down_complete, :clear_context

     route(/^\s*(.+)\s*$/i, :anything, command: false, help: { 'listen' => 'Say anything and the bot will listen' })

     def get_rezbot_logs
       log = redis.get(:logs)
       if log.nil?
         log = []
       else
         log = JSON.parse(log)
       end
       log
     end


     def log_message(entry)
       logs = get_logs
       logs << entry
       redis.set(:logs, logs.to_json)
     end

     def rezbot_log(heard,response)
       if heard == "rezbot_log"
         get_rezbot_logs.each_with_index do |entry,i|
           response.reply entry
        end
        return true
       end
     end

     def context
       ret = redis.get(:context)
       if ret.nil?
           set_context
           return :start
       end
       ret
     end

     def clear_context
      redis.del(:context)
     end

     def set_context
       redis.set(:context, :start)
     end

     def location(heard,response)
       if context == "location"
          locations = redis.get(:locations) || []
          if locations.include? heard
            response.reply "I see you have been here before"
          else
            locations << heard
            redis.set(:locations,locations)
            response.reply "This is a new place we are logging from ! great"
          end
          response.reply "Lets start by learning how you feel now; (Good, Bad, Worried, Happy etc')"
          redis.set(:context,:get_feeling)
          return true
       end
     end

     def feeling(heard,response)
       if context == "get_feeling"
         response.reply "to stop logging please type `Done.`"
         redis.set(:context,:capture_logs)
         return true
       end
     end

     def great(heard,response)
       if heard == "hello"
          redis.set(:context,:start)
          response.reply "Hi, what would you like to do today? (log, join a group, or learn something?)"
          return true
       end
     end

     def stop_log(heard,response)
       if heard == "Done."
          redis.set(:context,:start)
          response.reply "this is the log I captured"
          response.reply get_log
          return true
       end
     end

     def get_logs
       captured = redis.get(:user_logs)
       if captured.nil?
         captured = []
       else
         captured = JSON.parse(captured)
       end
       captured
     end


     def capture_logs(heard,response)
       if context == "capture_logs"
         #redis.set(:personal_logs, captured.to_json)
         add_log_text(heard)
         return true
       end
     end

     def show_log(heard,response)
       if heard == "show_log"
         get_logs.each_with_index do |entry,i|
           response.reply entry
        end
        return true
       end
     end

     def stop_capture(heard, response)
       if heard == "Done."
         response.reply "Log Captured"
         redis.set(:context,:done)
         return true
       end
     end

     def get_from_redis(key)
       data = redis.get(key)
       if data.nil?
         data = []
       else
         data = JSON.parse(data)
       end
       data
     end

     def get_current_log
       get_from_redis(:user_logs).last
     end

    def add_user_log
      user_logs = get_from_redis(:user_logs)
      user_logs << {time: Time.now}
      redis.set(:user_logs, user_logs.to_json)
    end

    def save_logs(log)
      puts log
      user_logs = get_from_redis(:user_logs)
      user_logs.pop
      user_logs.push(log)
      redis.set(:user_logs, user_logs.to_json)
    end

    def add_log_text(entry)
      puts entry
      log = get_current_log
      log["body"] ||= []
      log["body"] << entry
      save_logs(log)
    end

     def log(heard,response)
       if heard == "log"
         redis.set(:context,:location)
         log = add_user_log
         text = "creating a new log entry\n"
         text << "it is now #{Time.now}\n"
         text << "where are you ?"
         response.reply text
         return true
       end
     end

     def anything(response)
       heard = response.match_data[1]
       puts heard
       puts context
       log_message(heard)
       replied = rezbot_log(heard,response)
       replied = great(heard,response)
       replied = log(heard,response) unless replied
       replied = location(heard,response) unless replied
       replied = feeling(heard,response) unless replied
       replied = stop_capture(heard,response) unless replied
       replied = capture_logs(heard,response) unless replied
       replied = show_log(heard,response) unless replied
     end

      Lita.register_handler(self)
    end
  end
end
