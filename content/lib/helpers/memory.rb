
[
	"tool_messages.rb",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

class Memory
	attr_accessor :name, :start_address, :size, :contents, :permissions

	def initialize(name, start_address, size, contents=[])
		@name          = name
		@start_address = start_address
		@size          = size
		@contents      = contents
		@permissions   = "rw"
	end

	def permissions=(value)
		raise ToolException.new "Fatal error: permissions can only be passed as string" if value == nil || value.class != String
		raise ToolException.new "Fatal error: permissions can only be a collection of r/w flags" unless value =~ /^[rw]*$/i
		@permissions = value.downcase
	end

	def is_readable
		return @permissions.include?("r")
	end

	def is_writeable
		return @permissions.include?("w")
	end

	def write_byte(byte, address)
		raise ToolException.new "'#{@name}' is not writeable (permissions: '#{permissions}')" unless is_writeable
		raise ToolException.new "address '#{address}' for '#{@name}' is beyond range" unless is_address_within_bounds address
		index = address_to_index address
		@contents[index] = byte & 0xff
	end

	def read_byte(address)
		raise ToolException.new "'#{@name}' is not readable (permissions: '#{permissions}')" unless is_readable
		raise ToolException.new "address '#{address}' for '#{@name}' is beyond range" unless is_address_within_bounds address

		index = address_to_index address
		return @contents[index]
	end

	def is_address_within_bounds(address)
		return address_to_index(address) > -1
	end

	private 
	def address_to_index(address)
		address -= @start_address
		end_address = @size - @start_address - 1
		return -1 if address < 0 || address > end_address
		return address
	end

end