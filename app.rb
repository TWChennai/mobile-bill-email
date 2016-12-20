require 'sinatra'
require 'sinatra/streaming'
require 'sinatra/reloader' if development?
require 'haml'
require 'roo-xls'
require 'fileutils'
require 'mail'
require 'json'
require 'parallel'

class MobileMailer < Sinatra::Base
  get '/' do
    FileUtils.rm_r Dir.glob('./uploads/*.pdf')
    FileUtils.rm_r Dir.glob('./uploads/*.xls')
    FileUtils.rm_r Dir.glob('./uploads/extracted/*.pdf')
    haml :'partials/empty'
  end

  configure do
    set :header, nil
    set :data, nil
    set :name, ''
    set :server, 'puma'
    set :from_address, nil
    Mail.defaults do
      delivery_method :smtp, {
          :domain => "thoughtworks.com",
          :address => "smtp.gmail.com", :port => 587,
          :user_name => "",
          :password => "",
          :authentication => :plain,
          :enable_starttls_auto => true}
    end
  end

  post '/upload-bills' do
    rename_files(params['office'])
    store_file(params['xlsfile'])
    excel = Roo::Excel.new('./uploads/' + params['xlsfile'][:filename])
    sheet = excel.sheet(excel.sheets.last)
    settings.data = []
    settings.header = sheet.row(1)
    settings.from_address = params['from_address']
    settings.name = excel.sheets.last
    2.upto(sheet.last_row) do |row_num|
      begin
        row = sheet.row(row_num)
        next if row[9] == "N"
        mobile_number = row[2].to_int.to_s
        emp_id = row[0].to_int.to_s
        settings.data.push(row[0, 9])
        settings.data.last[0] = emp_id
        settings.data.last[2] = mobile_number
        settings.data.last.push(File.exists?(File.join("./uploads/extracted/", mobile_number + ".pdf")))
      rescue => e
        p "#{e} - no mobile bill\n\n #{row_num}"
      end
    end
    haml :'partials/success', :locals => {:data => settings.data, :name => settings.name, :from => settings.from_address}
  end

  post '/mobile-bills' do
    content_type :json
    response_hash = {}
    params['zipfiles'].each do |file_attr|
      store_file(file_attr)
      response_hash[file_attr[:filename]] = 'done'
    end
    response_hash.to_json
  end

  get '/send-mail', :provides => 'text/event-stream' do
    stream :keep_open do |out|
      Parallel.each(settings.data, :in_threads => 8) do |data|
        mail = Mail.new do
          html_part do
            content_type 'text/html; charset=UTF-8'
          end
          add_file :filename => "#{data[2]}.pdf",
                   :content => File.read(File.join("./uploads/extracted/", "#{data[2]}.pdf")) unless !data[9]
        end
        mail.from = settings.from_address
        mail.to = data[8]
        mail.subject = 'Your Airtel Bill - ' + settings.name
        mail.html_part.body = haml :'mail-template', :layout => false,
                                   :locals => {:headers => settings.header, :data => data, :name => settings.name}
        mail.deliver!
        out << "data:{\"index\":\"#{(data[8].split('@').first).split('.').first}\"}\n\n"
      end
    end
  end

  helpers do
    def store_file(file_attributes)
      File.open('./uploads/' + file_attributes[:filename], "w") do |f|
        f.write(file_attributes[:tempfile].read)
      end
    end

    def rename_files(office)
      Dir.glob('./uploads/*.pdf', File::FNM_CASEFOLD) do |file|
        original_file_name = /\/[^\/]+$/.match(file)[0]
        if office != '4' #not pune.
          match = original_file_name.match(/\d{10}(?!.*\d{10})/) #last 10 digits
          FileUtils.cp(file, './uploads/extracted/' + match[0] + ".pdf") unless match == nil
        else #pune
          FileUtils.cp(file, './uploads/extracted/' + original_file_name.split("-").first)
        end
      end
    end
  end
end
