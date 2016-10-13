
require "spec_helper"
require "helpers/memory"
require "helpers/memory_manager"
require "helpers/tool_messages"

describe MemoryManager do
	before(:each) do
		$mm = MemoryManager.new
		$dummy_memory1 = {}
		$dummy_memory2 = {}
		$dummy_memory3 = {}
		$mm.memories = [ $dummy_memory1, $dummy_memory2, $dummy_memory3 ]
	end

	describe "when parsing" do
		describe "raises error when" do
			it "parsed raw is nil or not an hash" do
				expect{ MemoryManager.parse nil }.to raise_exception(ToolException, "MemoryManager.parse: raw metadata must be a Hash")
				expect{ MemoryManager.parse 3 }.to raise_exception(ToolException, "MemoryManager.parse: raw metadata must be a Hash")
			end
		end

		it "parses each memory metadata and adds it to internal memories" do
			dummy_config = { 1 => 2, 3 => 4 }
			expect(Memory).to receive(:parse).with( { 1 => 2 } ).and_return('a')
			expect(Memory).to receive(:parse).with( { 3 => 4 } ).and_return('b')
			expect(MemoryManager).to receive(:sort_memories).with(['a', 'b']).and_return('result')
			expect(MemoryManager).to receive(:check_if_memories_overlap).with('result')

			mm = MemoryManager.parse dummy_config

			mm.memories.should be == 'result'
		end
	end

	describe "when checking memories for address overlap" do
		it "should raise exception when memories overlap" do
			$dummy_memory1 = Memory.new 'one', 0, 10, 8
			$dummy_memory2 = Memory.new 'two', 10, 20, 8
			$dummy_memory3 = Memory.new 'three', 29, 5, 8
			memories = [ $dummy_memory1, $dummy_memory2, $dummy_memory3 ]

			expect{ MemoryManager.check_if_memories_overlap memories }.to raise_exception(
				ToolException,
				"MemoryManager: memories overlap: 'two' (10, 20) and 'three' (29, 5)"
				)
		end
	end

	describe "when finding a memory by name, returns" do
		it "nil when no matching memory object is found" do
			$mm.memories = [ Memory.new('a', 23, 23, 8), Memory.new('b', 10, 40, 8) ]

			$mm.get_memory('c').should be == nil
		end

		it "returns matching memory object otherwise" do
			expected = Memory.new('b', 10, 40, 8)
			$mm.memories = [ Memory.new('a', 23, 23, 8), expected ]

			$mm.get_memory('B').should be == expected
		end
	end

	it "when sorting memories as per their address range should return the sorted result" do
		$dummy_memory1 = { 1 => 'a' }
		$dummy_memory2 = { 2 => 'a' }
		$dummy_memory3 = { 3 => 'a' }
		dummy_memories = [ $dummy_memory1, $dummy_memory2, $dummy_memory3 ]
		expect($dummy_memory1).to receive(:start_address).and_return(100)
		expect($dummy_memory2).to receive(:start_address).and_return(20)
		expect($dummy_memory3).to receive(:start_address).and_return(10)

		result = MemoryManager.sort_memories dummy_memories
		
		result.should be == [ $dummy_memory3, $dummy_memory2, $dummy_memory1 ]
	end

	describe "when writing a byte" do
		describe "without specifying a memory" do
			it "should raise an exception when the address does not exist" do
				expect($dummy_memory1).to receive(:address_exists?).with('address').and_return(false)
				expect($dummy_memory2).to receive(:address_exists?).with('address').and_return(false)
				expect($dummy_memory3).to receive(:address_exists?).with('address').and_return(false)

				expect{ $mm.write_byte 'address', 22 }.to raise_exception(ToolException, "MemoryManager.write_byte: address 'address' does not exist")
			end

			it "should delegate write operation to the found memory" do
				expect($dummy_memory1).to receive(:address_exists?).with('add').and_return(false)
				expect($dummy_memory2).to receive(:address_exists?).with('add').and_return(true)
				expect($dummy_memory2).to receive(:write_byte).with(0x34, 'add')

				$mm.write_byte 'add', 0x1234
			end
		end

		describe "by specifying a memory" do
			it "should raise an exception when specified memory could not be found" do
				expect($mm).to receive(:get_memory).with('memory').and_return(nil)

				expect{ $mm.write_byte 'address', 22, 'memory' }.to raise_exception(ToolException, "MemoryManager.write_byte: No memory found named as 'memory'")
			end

			it "should delegate write operation to the found memory" do
				expect($mm).to receive(:get_memory).with('m1m').and_return($dummy_memory1)
				expect($dummy_memory1).to receive(:write_byte).with(22, 'address')

				$mm.write_byte 'address', 22, 'm1m'
			end
		end
	end

	describe "when reading a byte" do
		describe "without specifying a memory" do
			it "should raise an exception when the address does not exist" do
				expect($dummy_memory1).to receive(:address_exists?).with(22).and_return(false)
				expect($dummy_memory2).to receive(:address_exists?).with(22).and_return(false)
				expect($dummy_memory3).to receive(:address_exists?).with(22).and_return(false)

				expect{ $mm.read_byte 22 }.to raise_exception(ToolException, "MemoryManager.read_byte: address '22' does not exist")
			end

			it "should delegate write operation to the found memory" do
				expect($dummy_memory1).to receive(:address_exists?).with(0x1234).and_return(false)
				expect($dummy_memory2).to receive(:address_exists?).with(0x1234).and_return(true)
				expect($dummy_memory2).to receive(:read_byte).with(0x1234).and_return('data')

				$mm.read_byte(0x1234).should be == 'data'
			end
		end

		describe "by specifying a memory" do
			it "should raise an exception when specified memory could not be found" do
				expect($mm).to receive(:get_memory).with('memory').and_return(nil)

				expect{ $mm.read_byte 'address', 'memory' }.to raise_exception(ToolException, "MemoryManager.read_byte: No memory found named as 'memory'")
			end

			it "should delegate write operation to the found memory" do
				expect($mm).to receive(:get_memory).with('m1m').and_return($dummy_memory1)
				expect($dummy_memory1).to receive(:read_byte).with('address').and_return('funky_data')

				$mm.read_byte('address', 'm1m').should be == 'funky_data'
			end
		end
	end

	describe "when checking if an address exists" do
		it "returns false when the address deos not exists in any of the memory" do
			expect($dummy_memory1).to receive(:address_exists?).with(432).and_return(false)
			expect($dummy_memory2).to receive(:address_exists?).with(432).and_return(false)
			expect($dummy_memory3).to receive(:address_exists?).with(432).and_return(false)

			$mm.address_exists?(432).should be == false
		end

		it "returns true when the address deos exist in some memory" do
			expect($dummy_memory1).to receive(:address_exists?).with(1001).and_return(false)
			expect($dummy_memory2).to receive(:address_exists?).with(1001).and_return(true)

			$mm.address_exists?(1001).should be == true
		end
	end

	describe "when obtaining memory object using" do
		describe "memory.name" do
			it "returns correct memory instance" do
				expect($mm).to receive(:get_memory).with("blah").and_return 2
				$mm["blah"].should be == 2
			end
			it "raises exception when no matching object is found" do
				expect($mm).to receive(:get_memory).with("blah").and_return nil
				expect { $mm["blah"] }.to raise_exception(ToolException, "MemoryManager[\"blah\"]: memory does not exists")
			end
		end
		describe "index" do
			it "returns correct memory instance" do
				dummy_memories = []
				$mm.memories   = dummy_memories
				expect(dummy_memories).to receive(:[]).with(23).and_return(2)
				$mm[23].should be == 2
			end
		end
	end

	it "when obtaining a list of memory names, returns correct list of names" do
		expect($dummy_memory1).to receive(:name).and_return('1')
		expect($dummy_memory1).to receive(:size).and_return(1)
		expect($dummy_memory2).to receive(:name).and_return('2')
		expect($dummy_memory2).to receive(:size).and_return(2)
		expect($dummy_memory3).to receive(:name).and_return('3')
		expect($dummy_memory3).to receive(:size).and_return(3)


		$mm.list.should be == {'1' => 1, '2' => 2, '3' => 3}
	end

	it "when iterating through each" do
		got_result = []
		$mm.each {  |m| got_result.push m }
		got_result.should be == [ $dummy_memory1, $dummy_memory2, $dummy_memory3 ]
	end
end
