# Janky .env loader
def load_dotenv(filename)
  File.readlines(filename).each do |line|
    arr = line.chomp.split("=",2)
    unless arr[0].nil? || arr[0].empty?
      puts "Setting #{arr[0]} environment variable = '#{arr[1]}'"
      ENV[arr[0]] = arr[1]
    end
  end
end

dotenv = File.join(Dir.pwd, '.env')
load_dotenv(dotenv) if File.exist?(dotenv)

cmdline = ARGV.join(' ')
exec(cmdline)
