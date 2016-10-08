
[
	"helpers/tool_messages.rb",
	"helpers/cpu.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }
require "yaml"


class Tinker
	attr_accessor :cpu,
	              :variables,       # contains a collection of all variables
	              :raw_hex_image,
	              :hex_file,
	              :meta_file

	def initialize
		@cpu = nil
		@variables = []
		@raw_hex_image = []
	end

	def []=(var_name, value)
		v = get_variable var_name
		begin
			cpu.write_memory v.memory_name, v.address, v.size, value
		rescue ToolException => ex
			raise ToolException.new "Tinker: error writing variable '#{v.name}': " + ex.message
		end
	end

	def [](var_name)
		v = get_variable var_name
		begin
			return cpu.read_memory v.memory_name, v.address, v.size
		rescue ToolException => ex
			raise ToolException.new "Tinker: error reading variable '#{v.name}': " + ex.message
		end
	end

	def get_variable(var_name)
		var_name.downcase!
		@variables.each {  |v| return v if v.name.downcase == var_name }
		raise ToolException.new "Tinker: variable not found ('#{var_name}')"
	end

	def Tinker.load_image(hex_file, meta_file)
		raise ToolException.new "Tinker: hex file ('#{hex_file}') does not exists" unless File.exists? hex_file
		raise ToolException.new "Tinker: meta file ('#{meta_file}') does not exists" unless File.exists? meta_file

		cpu_info, variables = Tinker.parse_meta_file meta_file
		raw_hex_image = File.readlines hex_file
		
		t = Tinker.new
		t.cpu           = CPU.parse cpu_info
		t.variables     = variables
		t.raw_hex_image = raw_hex_image
		t.hex_file      = hex_file
		t.meta_file     = meta_file

		t.cpu.mount_hex raw_hex_image
		return t
	end

	def force_default_value
		raise "Not Implemented!"
	end

	def to_hex_file(file)
		raise "Not Implemented!"
	end

	private 
	def Tinker.parse_meta_file(raw_meta)
		raw_meta = YAML.load_file(raw_meta)[:meta]
		variables = []
		symbols = raw_meta[:data]
		symbols.each_pair {  |name, raw| 
				variables.push Variable.parse name, raw
			} if symbols
		return raw_meta[:cpu], variables
	end

	def Tinker.mount_cpu_info(raw)
		return unless raw
		@cpu = CPU.parse raw
	end
end
