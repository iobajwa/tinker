
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


=begin
	format:
	:<name>:
		:start_address:
		:size:
=end
	def Memory.parse(raw)
		raise ToolException.new "Memory.parse: only Hash datatype is supported" if raw == nil || raw.class != Hash
		raise ToolException.new "Memory.parse: nothing to parse" if raw.length == 0

		name = raw.keys[0]
		meta = raw [ name ]
		name = name.to_s
		size          = meta[:size]
		start_address = meta[:start_address]

		raise ToolException.new "Memory.parse: size not defined for '#{name}'" unless size
		raise ToolException.new "Memory.parse: size can only be a number ('#{name}')" unless size.class == Fixnum
		raise ToolException.new "Memory.parse: size can not be less than 1 ('#{name}')" if size < 1
		raise ToolException.new "Memory.parse: start_address not defined for '#{name}'" unless start_address
		raise ToolException.new "Memory.parse: start_address can only be a number ('#{name}')" unless start_address.class == Fixnum
		raise ToolException.new "Memory.parse: start_address can not be less than 0 ('#{name}')" if start_address < 1

		return Memory.new name, meta[:start_address], meta[:size]
	end


	private 
	def address_to_index(address)
		end_address = @start_address + @size - 1
		return -1 if address < @start_address || address > end_address
		return address - @start_address
	end

end