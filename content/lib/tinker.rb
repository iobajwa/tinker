
class Tinker
	attr_accessor :cpu,
	              :symbols       # a hash of all symbols

	def initialize
		@cpu = CPU.new
		@symbols = {}
	end

	def from_hex_file(file)
	end

	def to_hex_file(file)
	end
end
