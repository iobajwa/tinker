
require "spec_helper"
require "helpers/memory"
require "helpers/tool_messages"

describe Memory do
	before(:each) do
		$memory = Memory.new('m', 2, 20)
	end

	describe "when checking if an address is within the memory bounds" do
		it "returns true when it lies within the range" do
			within_bounds = $memory.is_address_within_bounds 19
			within_bounds.should be == true

			within_bounds = $memory.is_address_within_bounds 2
			within_bounds.should be == true
		end

		it "returns false otherwise" do
			within_bounds = $memory.is_address_within_bounds 1
			within_bounds.should be == false

			within_bounds = $memory.is_address_within_bounds 20
			within_bounds.should be == false
		end
	end

	describe "when setting permissions" do
		describe "should raise exception when" do
			it "passed permissions are nil" do
				expect{ $memory.permissions = nil }.to raise_exception(ToolException, "Fatal error: permissions can only be passed as string")
			end
			it "passed permissions are of class other than String" do
				expect{ $memory.permissions = 2 }.to raise_exception(ToolException, "Fatal error: permissions can only be passed as string")
			end

			it "passed permissions contain invalid flags" do
				expect{ $memory.permissions = "d" }.to raise_exception(ToolException, "Fatal error: permissions can only be a collection of r/w flags")
			end
		end

		it "should set the new values" do
			$memory.permissions = 'r'
			$memory.permissions.should be == 'r'

			$memory.permissions = 'w'
			$memory.permissions.should be == 'w'
		end
	end

	describe "when interogating if the memory is readable, should return" do
		it "true if permissions has the 'r' flag" do
			$memory.is_readable.should be == true

			$memory.permissions = "R"
			$memory.is_readable.should be == true
		end

		it "false otherwise" do
			$memory.permissions = "w"
			$memory.is_readable.should be == false
		end
	end

	describe "when interogating if the memory is writeable, should return" do
		it "true if permissions has the 'w' flag" do
			$memory.is_writeable.should be == true

			$memory.permissions = "W"
			$memory.is_writeable.should be == true
		end

		it "false otherwise" do
			$memory.permissions = "r"
			$memory.is_writeable.should be == false
		end
	end

	describe "when writing to memory" do
		describe "should raise exception when" do
			it "memory is not writable" do
				expect($memory).to receive(:is_writeable).and_return(false)
				expect{ $memory.write_byte 23, 0 }.to raise_exception(ToolException, "'m' is not writeable (permissions: 'rw')")
			end

			it "address is beyond range" do
				$memory.start_address = 10
				$memory.size = 5

				expect($memory).to receive(:is_writeable).and_return(true)
				expect($memory).to receive(:is_address_within_bounds).and_return(false)
				expect{ $memory.write_byte 23, 9 }.to raise_exception(ToolException, "address '9' for 'm' is beyond range")

				expect($memory).to receive(:is_writeable).and_return(true)
				expect($memory).to receive(:is_address_within_bounds).and_return(false)
				expect{ $memory.write_byte 23, 15 }.to raise_exception(ToolException, "address '15' for 'm' is beyond range")
			end
		end

		it "writes a single byte to the designated address" do
			expect($memory).to receive(:is_writeable).and_return(true)
			expect($memory).to receive(:is_address_within_bounds).and_return(true)

			$memory.write_byte 0x1234, 4

			$memory.contents.should be == [nil, nil, 0x34]
		end
	end

	describe "when reading from memory" do
		describe "should raise exception when" do
			it "memory is not readable" do
				expect($memory).to receive(:is_readable).and_return(false)
				expect{ $memory.read_byte 0 }.to raise_exception(ToolException, "'m' is not readable (permissions: 'rw')")
			end

			it "address is beyond range" do
				$memory.start_address = 10
				$memory.size = 5

				expect($memory).to receive(:is_readable).and_return(true)
				expect($memory).to receive(:is_address_within_bounds).and_return(false)
				expect{ $memory.read_byte 9 }.to raise_exception(ToolException, "address '9' for 'm' is beyond range")

				expect($memory).to receive(:is_readable).and_return(true)
				expect($memory).to receive(:is_address_within_bounds).and_return(false)
				expect{ $memory.read_byte 15 }.to raise_exception(ToolException, "address '15' for 'm' is beyond range")
			end
		end

		it "reads a single byte from the designated address" do
			$memory.contents = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			expect($memory).to receive(:is_readable).and_return(true)

			read_byte = $memory.read_byte 2

			read_byte.should be == 0
		end
	end

end
