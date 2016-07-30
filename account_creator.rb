require 'nokogiri'
require 'net/http'
require 'digest/md5'
require 'open-uri'
require 'openssl'
require 'certified'
require 'httpclient' 

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

	# Setup HTTPClient
	httpclient = HTTPClient.new
	httpclient.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

	# Pull sign up page
	sign_up_url = "https://club.pokemon.com/us/pokemon-trainer-club/sign-up/"

	registration_form_response = httpclient.get(sign_up_url)

	registration_form_html_parsed = Nokogiri::HTML(registration_form_response.body)

	# Get variables for the initial sign up request
	csrf_token = get_csrf_token(registration_form_html_parsed)

	sign_up_parameters = {
		'csrfmiddlewaretoken' => csrf_token,
		'dob' => "#{1950 + rand(45)}-0#{1 + Random.rand(8)}-#{Random.rand(28)}",
		'country' => "US"
	}.map{|k,v| "#{k}=#{v}"}.join('&')

	headers = {
		'Referer' => sign_up_url
	}

	# Send initial signup request
	sign_up_response = httpclient.post(sign_up_url, sign_up_parameters, headers)
	# We don't really need the info coming from this page, so we'll just build the next parameters

	# Setup final signup request
	final_signup_url = "https://club.pokemon.com/us/pokemon-trainer-club/parents/sign-up"

	final_signup_form_response = httpclient.get(final_signup_url)

	o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
	username = (0...12).map { o[rand(o.length)] }.join
	password = (0...12).map { o[rand(o.length)] }.join
	email = "#{username.downcase}@divismail.ru"
	md5_email = Digest::MD5.hexdigest(email)

	final_signup_parameters = {
		'csrfmiddlewaretoken' => csrf_token,
		'username' => username,
		'password' => password,
		'confirm_password' => password,
		'email' => email,
		'confirm_email' => email,
		'public_profile_opt_in' => 'False',
		'screen_name' => '',
		'terms' => 'on'
	}.map{|k,v| "#{k}=#{v}"}.join('&')

	headers = {
		'Referer' => final_signup_url
	}

	# Send final sign up request

	response = httpclient.post(final_signup_url, final_signup_parameters, headers)

	response = httpclient.get("https://club.pokemon.com/us/pokemon-trainer-club/parents/email")

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

	# TIME TO LOGIN!

	# Let's get the login form
	login_url = "https://sso.pokemon.com/sso/login?locale=en&service=https://club.pokemon.com/us/pokemon-trainer-club/caslogin"
	response = httpclient.get(login_url)
	doc = Nokogiri::HTML(response.body)

	lt = doc.css("#login-form > input[type=\"hidden\"]:nth-child(1)").attr('value')
	execution = doc.css("#login-form > input[type=\"hidden\"]:nth-child(2)").attr('value')
	_eventId = doc.css("#login-form > input[type=\"hidden\"]:nth-child(3)").attr('value')

	login_parameters = {
		"lt" => lt,
		"execution" => execution,
		"_eventId" => _eventId,
		"username" => username,
		"password" => password,
		"Login" => "Sign In"
	}.map{|k,v| "#{k}=#{v}"}.join('&')
	# Send Login Post

	headers = {
		'Referer' => login_url
	}

	login_response = httpclient.post(login_url, login_parameters, headers)

	
	# Loop through redirects to get all cookies. This sucks but has to be done.
	while(login_response.code == 302)
		login_response = httpclient.get(URI(login_response.headers["Location"]))
	end

	# Time to accept TOS!

	tos_page = 'https://club.pokemon.com/us/pokemon-trainer-club/go-settings'

	tos_page_html = httpclient.get(tos_page).body

	tos_parameters = {
		'csrfmiddlewaretoken' => get_csrf_token(Nokogiri::HTML(tos_page_html)),
		'go_terms' => ' on'
	}.map{|k,v| "#{k}=#{v}"}.join('&')

	headers = {
		'Referer' => tos_page
	}

	response = httpclient.post(tos_page, tos_parameters, headers)


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
	rescue => e
		puts e
		puts "[Try: #{try_count}] Failed"
		try_count += 1
	end
end
puts "PTC Account Creator Done"