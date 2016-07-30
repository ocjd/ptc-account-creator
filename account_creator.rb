require 'nokogiri'
require 'net/http'
require 'digest/md5'
require 'open-uri'
require 'openssl'
require 'certified'

def get_csrf_token(doc)
	csrf_token = doc.css('form > input[type="hidden"]').first
	csrf_token = csrf_token.attr('value')
	csrf_token
end

def parse_cookies(all_cookies)
	cookies_array = Array.new
    all_cookies.each { | cookie |
        cookies_array.push(cookie.split('; ')[0])
    }
    cookies = cookies_array.join('; ')
    cookies
end

def create_account

	http = Net::HTTP.new('club.pokemon.com', 443)
	http.use_ssl = true
	http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	path = '/us/pokemon-trainer-club/sign-up/'

	response = http.get(path, nil)

	cookies = response.code == '200' ? parse_cookies(response.get_fields('set-cookie')) : ""

	doc = Nokogiri::HTML(response.body)

	csrf_token = get_csrf_token(doc)

	params = {
		'csrfmiddlewaretoken' => csrf_token,
		'dob' => "1957-07-10",
		'country' => "US"
	}

	params = params.map{|k,v| "#{k}=#{v}"}.join('&')

	headers = {
		'Cookie' => cookies,
		'Referer' => 'https://club.pokemon.com/us/pokemon-trainer-club/sign-up/',
		'Content-Type' => 'application/x-www-form-urlencoded'
	}

	res, data = http.post(path, params, headers)

	req = http.get("/us/pokemon-trainer-club/parents/sign-up", {'Cookie' => cookies})

	o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
	username = (0...12).map { o[rand(o.length)] }.join
	password = (0...12).map { o[rand(o.length)] }.join
	email = "#{username.downcase}@divismail.ru"
	md5_email = Digest::MD5.hexdigest(email)

	params = {
		'csrfmiddlewaretoken' => csrf_token,
		'username' => username,
		'password' => password,
		'confirm_password' => password,
		'email' => email,
		'confirm_email' => email,
		'public_profile_opt_in' => 'False',
		'screen_name' => '',
		'terms' => 'on'
	}

	params = params.map{|k,v| "#{k}=#{v}"}.join('&')

	headers = {
		'Cookie' => cookies,
		'Referer' => 'https://club.pokemon.com/us/pokemon-trainer-club/parents/sign-up',
		'Content-Type' => 'application/x-www-form-urlencoded'
	}


	res, data = http.post('/us/pokemon-trainer-club/parents/sign-up', params, headers)

	response = http.get("/us/pokemon-trainer-club/parents/email", {'Cookie' => cookies})

	# Time to do email validation

	email_arrived = false
	email_response = ""

	while !email_arrived
		begin
			res = open("http://api.temp-mail.ru/request/mail/id/#{md5_email}").read
			email_response = res
			email_arrived = true
		rescue
			sleep 5
		end
	end

	xml = Nokogiri::XML(email_response)
	mail_text = xml.xpath("//item")[0].xpath("//mail_text_only")
	mail_text = Nokogiri::HTML(mail_text.text)

	validate_link = mail_text.css("body > table > tbody > tr:nth-child(7) > td > table > tbody > tr > td:nth-child(2) > a").attr('href').value

	validated = false
	while !validated
		validation_response = open(URI(validate_link)).read
		validated = validation_response.include?("Thank you for signing up! Your account is now active.") ? true : false
	end

	File.open("accounts.txt", 'a') do |file|
		file.puts "#{username}:#{password}"
	end
end

times = 10
counter = 0
try_count = 0
puts "PTC Account Creator Started"
while(counter < times)
	begin
		create_account
		counter += 1
		puts "[Try: #{try_count}] #{counter} Accounts created"
		try_count += 1
	rescue
		puts "[Try: #{try_count}] Failed"
		try_count += 1
	end
end