
require "spec_helper"
require "helpers/memory"
require "helpers/tool_messages"

describe Memory do
	before(:each) do
		$memory = Memory.new 'm', 2, 20, 8
	end

	describe "when checking if an address is within the memory bounds" do
		it "returns true when it lies within the range" do
			within_bounds = $memory.address_exists?(19).should be == true
			within_bounds = $memory.address_exists?(2).should be == true
		end

		it "returns false otherwise" do
			$memory.address_exists?(1).should be == false
			$memory.address_exists?(22).should be == false
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
			$memory.is_readable?.should be == true

			$memory.permissions = "R"
			$memory.is_readable?.should be == true
		end

		it "false otherwise" do
			$memory.permissions = "w"
			$memory.is_readable?.should be == false
		end
	end

	describe "when interogating if the memory is writeable, should return" do
		it "true if permissions has the 'w' flag" do
			$memory.is_writeable?.should be == true

			$memory.permissions = "W"
			$memory.is_writeable?.should be == true
		end

		it "false otherwise" do
			$memory.permissions = "r"
			$memory.is_writeable?.should be == false
		end
	end

	describe "when writing to memory" do
		describe "should raise exception when" do
			it "memory is not writable" do
				expect($memory).to receive(:is_writeable?).and_return(false)
				expect{ $memory.write_byte 23, 0 }.to raise_exception(ToolException, "'m' is not writeable (permissions: 'rw')")
			end

			it "address is beyond range" do
				$memory.start_address = 10
				$memory.size = 5

				expect($memory).to receive(:is_writeable?).and_return(true)
				expect($memory).to receive(:address_exists?).and_return(false)
				expect{ $memory.write_byte 23, 9 }.to raise_exception(ToolException, "address '9' for 'm' is beyond range")

				expect($memory).to receive(:is_writeable?).and_return(true)
				expect($memory).to receive(:address_exists?).and_return(false)
				expect{ $memory.write_byte 23, 15 }.to raise_exception(ToolException, "address '15' for 'm' is beyond range")
			end
		end

		it "writes a single byte to the designated address" do
			expect($memory).to receive(:is_writeable?).and_return(true)
			expect($memory).to receive(:address_exists?).and_return(true)

			$memory.write_byte 0x1234, 4

			$memory.contents.should be == [nil, nil, 0x34]
		end
	end

	describe "when reading from memory" do
		describe "should raise exception when" do
			it "memory is not readable" do
				expect($memory).to receive(:is_readable?).and_return(false)
				expect{ $memory.read_byte 0 }.to raise_exception(ToolException, "'m' is not readable (permissions: 'rw')")
			end

			it "address is beyond range" do
				$memory.start_address = 10
				$memory.size = 5

				expect($memory).to receive(:is_readable?).and_return(true)
				expect($memory).to receive(:address_exists?).and_return(false)
				expect{ $memory.read_byte 9 }.to raise_exception(ToolException, "address '9' for 'm' is beyond range")

				expect($memory).to receive(:is_readable?).and_return(true)
				expect($memory).to receive(:address_exists?).and_return(false)
				expect{ $memory.read_byte 15 }.to raise_exception(ToolException, "address '15' for 'm' is beyond range")
			end
		end

		it "reads a single byte from the designated address" do
			$memory.contents = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			expect($memory).to receive(:is_readable?).and_return(true)

			read_byte = $memory.read_byte 2

			read_byte.should be == 0
		end
	end

	describe "when reading object from memory" do
		describe "raises exception when" do
			it "memory is not readable" do
				expect($memory).to receive(:is_readable?).and_return(false)
				expect{ $memory.read_object 15, 2 }.to raise_exception(ToolException, "'m' is not readable (permissions: 'rw')")
			end
			it "address is beyond range" do
				expect($memory).to receive(:is_readable?).and_return(true)
				expect($memory).to receive(:address_exists?).with(15).and_return(false)
				expect{ $memory.read_object 15, 2 }.to raise_exception(ToolException, "address '15' for 'm' is beyond range")
			end
			it "cell_size is greater than 1 byte and address is not byte alligned" do
				expect($memory).to receive(:is_readable?).and_return(true)
				expect($memory).to receive(:address_exists?).and_return(true)
				expect($memory).to receive(:address_to_index).with(2).and_return(2)
				$memory.size = 23
				expect { $memory.read_object 2, 2 }.to raise_exception(ToolException, "address '2' for 'm' is not cell-alligned")
			end
		end
		describe "returns deserialized object when" do
			before(:each) do
				$memory.contents = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			end
			describe "memory is little-endian and" do
				before(:each) do
					$memory.endian = :little
				end
				it "cell_size is 1 byte" do
					expect($memory).to receive(:is_readable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(3)
					$memory.cell_size = 1
					$memory.padding   = nil

					obj = $memory.read_object 1, 2

					obj.should be == [3, 4]
				end
				it "cell_size is > 1 byte" do
					expect($memory).to receive(:is_readable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(2)
					$memory.cell_size  = 2
					$memory.data_index = 1

					obj = $memory.read_object 1, 3

					obj.should be == [3, 5, 7]
				end
			end

			describe "memory is big-endian and" do
				before(:each) do
					$memory.endian = :big
				end
				it "cell_size is 1 byte" do
					expect($memory).to receive(:is_readable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(3)
					$memory.cell_size = 1
					$memory.padding   = nil

					obj = $memory.read_object 1, 2

					obj.should be == [4, 3]
				end
				it "cell_size is > 1 byte" do
					expect($memory).to receive(:is_readable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(0)
					$memory.cell_size  = 2
					$memory.data_index = 1

					obj = $memory.read_object 1, 3

					obj.should be == [5, 3, 1]
				end
			end
		end
	end

	describe "when writing object to memory" do
		describe "raises exception when" do
			it "memory is not writeable" do
				expect($memory).to receive(:is_writeable?).and_return(false)
				expect{ $memory.write_object [1], 15 }.to raise_exception(ToolException, "'m' is not writeable (permissions: 'rw')")
			end
			it "address is beyond range" do
				expect($memory).to receive(:is_writeable?).and_return(true)
				expect($memory).to receive(:address_exists?).with(15).and_return(false)
				
				expect{ $memory.write_object [1], 15 }.to raise_exception(ToolException, "address '15' for 'm' is beyond range")
			end
			it "cell_size is greater than 1 byte and address is not byte alligned" do
				expect($memory).to receive(:is_writeable?).and_return(true)
				expect($memory).to receive(:address_exists?).and_return(true)
				expect($memory).to receive(:address_to_index).with(2).and_return(2)
				$memory.size = 23
				expect { $memory.write_object [2, 2], 2 }.to raise_exception(ToolException, "address '2' for 'm' is not cell-alligned")
			end
		end
		describe "returns deserialized object when" do
			before(:each) do
				$memory.contents = []
			end
			describe "memory is little-endian and" do
				before(:each) do
					$memory.endian = :little
				end
				it "cell_size is 1 byte" do
					expect($memory).to receive(:is_writeable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(3)
					$memory.cell_size = 1

					$memory.write_object [1, 2, 3, 4], 1

					$memory.contents.should be == [nil, nil, nil, 1, 2, 3, 4]
				end
				it "cell_size is > 1 byte" do
					expect($memory).to receive(:is_writeable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(3)
					$memory.cell_size = 3
					$memory.padding = 0x1234
					$memory.data_index = 2

					$memory.write_object [1, 2], 1

					$memory.contents.should be == [nil, nil, nil, 0x34, 0x12, 1, 0x34, 0x12, 2]
				end
			end

			describe "memory is big-endian and" do
				before(:each) do
					$memory.endian = :big
				end
				it "cell_size is 1 byte" do
					expect($memory).to receive(:is_writeable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(3)
					$memory.cell_size = 1

					$memory.write_object [1, 2, 3, 4], 1

					$memory.contents.should be == [nil, nil, nil, 4, 3, 2, 1]
				end
				it "cell_size is > 1 byte" do
					expect($memory).to receive(:is_writeable?).and_return(true)
					expect($memory).to receive(:address_exists?).and_return(true)
					expect($memory).to receive(:address_to_index).with(1).and_return(3)
					$memory.cell_size = 3
					$memory.padding = 0x1234
					$memory.data_index = 0

					$memory.write_object [1, 2], 1

					$memory.contents.should be == [nil, nil, nil, 2, 0x12, 0x34, 1, 0x12, 0x34]
				end
			end
		end
	end

	describe "when parsing memory object from metadata" do
		describe "should raise exception when" do
			it "passed metadata is of class other than Hash" do
				expect{ Memory.parse 'd' }.to raise_exception(ToolException, "Memory.parse: only Hash datatype is supported")
			end

			it "empty hash is passed" do
				expect{ Memory.parse({}) }.to raise_exception(ToolException, "Memory.parse: nothing to parse")
			end

			it "size is missing" do
				dummy_config = { :memory => { :start_address => 0x100 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: size missing for 'memory'")
			end

			it "size is not a number" do
				dummy_config = { :m => { :size => 'a', :start_address => 0x100 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: size can only be a number ('m')")
			end

			it "size is less than 1" do
				dummy_config = { :m => { :size => 0, :start_address => 0x100 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: size cannot be less than 1 ('m')")

				dummy_config = { :m => { :size => -1, :start_address => 0x100 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: size cannot be less than 1 ('m')")
			end

			it "starting address is missing" do
				dummy_config = { :m => { :size => 32, } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: start_address missing for 'm'")
			end

			it "starting address is not a number" do
				dummy_config = { :m => { :size => 32, :start_address => 'add'} }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: start_address can only be a number ('m')")
			end

			it "starting address is less than 0" do
				dummy_config = { :m => { :size => 32, :start_address => -23} }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: start_address cannot be less than 0 ('m')")
			end

			it "cell_size is missing" do
				dummy_config = { :m => { :size => 32, :start_address => 1 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: cell_size missing for 'm'")
			end

			it "cell_size is < 1" do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 0 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: cell_size cannot be less than 1 ('m')")
			end
			
			it "data_index is missing" do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 2 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: data_index missing for 'm'")
			end

			it "data_index is < 0" do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 2, :data_index => -1 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: data_index cannot be less than 0 ('m')")
			end

			it "data_index is >= cell_size" do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 2, :data_index => 2 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: data_index cannot be >= cell_size ('m')")
			end

			it "padding is missing" do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 2, :data_index => 0 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: padding missing for 'm'")
			end

			it "padding is < 0" do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 2, :data_index => 0, :padding => -1 } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: padding cannot be less than 0 ('m')")
			end

			it "endian is neither :big nor :little " do
				dummy_config = { :m => { :size => 32, :start_address => 1, :cell_size => 2, :data_index => 0, :padding => 23, :endian => :what? } }
				expect{ Memory.parse dummy_config }.to raise_exception(ToolException, "Memory.parse: endian can only be :big or :little ('m')")
			end
		end

		describe "should parse and return a valid memory object when" do
			it "cell_size is 1" do
				dummy_config = { :memory => { :size => 32, :start_address => 0x100, :cell_size => 1, :endian => :big } }

				memory = Memory.parse dummy_config, :little

				memory.name.should be          == "memory"
				memory.size.should be          == 32
				memory.start_address.should be == 0x100
				memory.cell_size.should be     == 1
				memory.padding.should be_nil
				memory.data_index.should be    == 0
				memory.endian.should be        == :little
			end
			it "padding byte is provided" do
				dummy_config = { :memory => { :size => 32, :start_address => 0x100, :cell_size => 54, :data_index => 12, :padding => 43, :endian => :big } }

				memory = Memory.parse dummy_config

				memory.name.should be          == "memory"
				memory.size.should be          == 32
				memory.start_address.should be == 0x100
				memory.cell_size.should be     == 54
				memory.data_index.should be    == 12
				memory.padding.should be       == 43
				memory.endian.should be        == :big
			end
		end
	end
end
