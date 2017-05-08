require 'webrick'
 
include WEBrick


def start_webrick(config = {})
  config.update(:Port => 2345)     
  server = HTTPServer.new(config)
  yield server if block_given?
  ['INT', 'TERM'].each {|signal| 
    trap(signal) {server.shutdown}
  }
  server.start
end

class RestServlet < HTTPServlet::AbstractServlet
  $log_data = Array.new
  def do_GET(req,resp)
      # Split the path into pieces, getting rid of the first slash
      path = req.path[1..-1].split('/')
      if path.empty?
        path.push('dsrs')
      end
      $log_data.push(req)
      raise HTTPStatus::NotFound if !RestServiceModule.const_defined?(path[0].upcase)
      response_class = RestServiceModule.const_get(path[0].upcase)

      if response_class and response_class.is_a?(Class)
        # There was a method given
        if path[1]
          response_method = path[1].to_sym.upcase
          # Make sure the method exists in the class
          raise HTTPStatus::NotFound if !response_class.respond_to?(response_method)
          # Remaining path segments get passed in as arguments to the method
          if path.length > 2
            resp.body = response_class.send(response_method, path[2..-1])
          else
            resp.body = response_class.send(response_method)
          end
          raise HTTPStatus::OK
        # No method was given, so check for an "index" method instead
        else
          raise HTTPStatus::NotFound if !response_class.respond_to?(:index)
          resp.body = response_class.send(:index)
          raise HTTPStatus::OK
        end
      else
        raise HTTPStatus::NotFound
      end
  end
end
 
module RestServiceModule
  class DSRS
    def self.index()
      return "<html>" + "<body>" + "<b>" + "Welcome to the Damn Shitty Ruby Script" + "<br />" + "<a href='http://127.0.0.1:2345/nslookup/'>Try NSLOOKUP</a>" + "<br />" + "<a href='http://127.0.0.1:2345/HTML/INJECTION/HELLO'>Try HTML INJECTION</a>" + "<br />" + "<a href='http://127.0.0.1:2345/LFI/FILE/Spage=localscript.txt'>Try Local File Inclusion</a>" + "<br />" + "<a href='http://127.0.0.1:2345/RFI/VULN/page=https://raw.githubusercontent.com/rschwass/SCRIPTS/master/remotefile.rb'>Try Remote File Inclusion</a>" + "<br />" + "<a href='http://127.0.0.1:2345/XSS/STORED'>LOG VIEW Stored XSS</a>" + "<br />" + "<a href='http://127.0.0.1:2345/INJECTABLE/INJECTABLE/string='>LETS PRACTICE INJECTING</a>" + "</body>" + "</html>"
    end
  end
  class XSS
    def self.index()
      return "<html>" + "<body>" + "<b>" + "JS XSS PAGE!" + "</b>" + "<br />" + "<a href='http://127.0.0.1:2345/XSS/STORED'>XSS STORED-LOG VIEWER</a>" + "<br />" + "<a href='http://127.0.0.1:2345/XSS/CLEAR'>CLEAR LOG VIEWER</a>" + "</body>" + "</html>"
    end
    def self.STORED
      puts $log_data.join(' ')
      return "<html>" + "<body>" + "<b>" + "LOG VIEWER:"  + "</b>" + "<br />" + $log_data.join(' ') + "</body>" + "</html>"
    end
    def self.CLEAR
      $log_data = Array.new
      return "<html>" + "<body>" + "<b>" + "Logs Cleared"  + "</b>" + "<br />" + "</body>" + "</html>"
    end
  end
  class INJECTABLE
    def self.index()
    end
    def self.INJECTABLE(*data)
      data = data.join('/').split(/string=/i)[1]
      puts data
      return "<html>Use INJECTABLE/INJECTABLE/string='your crap' </br>you can inject almost anything into this url. Please Have fun! I will spit it out HERE:#{data}</html>"
    end
  end
  class HTML
    def self.index()
      return "PUT SOME JUNK IN MY URL"
    end
    def self.INJECTION(data)
      return  "<html>" + "<body>" + "<b>" + "From the URL: " + data.join + "</b>" "</body>" + "</html>"
    end
  end
  class LFI
    def self.index()
      return "VULN Found at LFI/FILE/page="
    end
    def self.FILE(data)
      File.write('localscript.rb', "string = 'This is from a local script'")
      file = data.join('/').split(/page=/i)[1]
      puts file
      while File.exists?(file)
        puts "#{file} Exists"
        if file.split('.')[1] == 'TXT'
          data = open(file) { |f| f.read}
          data = eval(data)
        else
          data = open(file) { |f| f.read}
        end
        return data
        break
      end
      return "File Does not exist"
    end
  end
  class NSLOOKUP
    def self.index()
      return "<html>" + "<body>" + "<b>" + "NSLOOKUP!" + "</b>" + "<br />" + "HOSTNAME:" + "<input type='text' id='input1' name='hostname' />" + "<button onclick='myjs()'>SUBMIT!</button><script type='text/javascript'>function myjs(){var text01=document.getElementById('input1').value;document.location='http://127.0.0.1:2345/NSLOOKUP/HOSTNAME/' + text01;}</script>"+ "<br>" + "</body>" + "</html>"
    end
    def self.HOSTNAME(data)
      data=data.join
      puts "Command String = #{data}"
      command = `nslookup #{data}`
      return "<html>" + "<body>" + "<b>" + command + "</b>" + "<br />" + "</body>" + "</html>"
    end
  end
  class RFI
    def self.index()
      return "<html>" + "<body>" + "Tamper with the" + "<b>" + " 'page=' " + "</b>" + "parameter in my url" + "<br />" + "</body>" + "</html>"
    end
    def self.VULN(data)
      data = data.join('//')
      #search for https in urlstring
      if !data.slice(/HTTPS/i).nil?
        prefix = "HTTPS:"
      else
        prefix = "HTTP:"
      end
      puts data
      #sanatize url string
      data = data.gsub(/HTTP:/i, "").gsub(/HTTPS:/i, "").gsub(/PAGE=/i, "").gsub('//', '/')
      #Remove leading '/' if it exists
      if data[0] == '/'
        data = data[1..-1]
      end
      #rebuild url
      data = prefix + '//' + data
      puts "look here " + data
      #open file
      require 'open-uri'
      require 'net/http'
      url_string = data
      url = URI.parse(url_string)
      req = Net::HTTP.new(url.host, url.port)
      req.use_ssl = true if url.scheme == 'https'
      res = req.request_head(url.path)
      if res.code == '404'
        data = "404 NOT FOUND"
      elsif res.code == '200'
        puts url_string
        data  = open(url_string) { |f| f.read}
        data = eval(data)
      end
      return "<html>" + "<body>" + "<b>" + data + "<br />" + "</body>" + "</html>"
    end     
  end
end
 
start_webrick { | server |
  server.mount('/', RestServlet)
}
