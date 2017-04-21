
require "spec_helper"
require "helpers/cpu"
require "helpers/memory"
require "helpers/memory_manager"
require "helpers/tool_messages"

describe CPU do
	describe "when parsing the cpu structure from raw data" do
		describe "and parsing name from passed string" do
			it "raises exception when passed raw string contains no name" do
				expect { CPU.parse_names ", , ,\r\n," }.to raise_exception(ToolException, "CPU.parse: no cpu name provided")
				expect { CPU.parse_names "" }.to raise_exception(ToolException, "CPU.parse: no cpu name provided")
			end

			it "returns array of names otherise" do
				parsed_names = CPU.parse_names "a,B, c ,\r\nd,"
				parsed_names.should be == ["a", "b", "c", "d"]
			end
		end

		describe "and finding a matching cpu metadata" do
			it "raises exception when no cpu is found" do
				expect(CPU).to receive(:known_cpus).and_return({'a' => { :alises => ['ah'] }, 'k' => {:aliases => ['c.', 'b.'], :metadata => 'bah'}})
				
				expect { CPU.find_cpu_metadata ["m"] }.to raise_exception(ToolException, "CPU.parse: no matching cpu found from '[\"m\"]'")
			end

			describe "returns hash containing metadata of matched cpu when" do
				it "passed name matches exact" do
					expect(CPU).to receive(:known_cpus).and_return({'a' => {:metadata => 'ah'}, 'b' => {:metadata => 'bah'}})
					
					found_metadata = CPU.find_cpu_metadata ["b"]
					
					found_metadata.should be == { :metadata => 'bah' }
				end
				
				it "an alias matches" do
					expect(CPU).to receive(:known_cpus).and_return({'a' => { :alises => ['ah'] }, 'k' => { :aliases => ['c.', 'b.'] }})
					
					found_metadata = CPU.find_cpu_metadata ["b", "b."]
					
					found_metadata.should be == { :aliases => ['c.', 'b.'] }
				end
			end
		end

		describe "raises exception when" do
			it "raw is passed nil" do
				expect { CPU.parse nil }.to raise_exception(ToolException, "CPU.parse: nothing to parse")
			end

			it "raw.class is something other than a hash or string" do
				expect { CPU.parse 23 }.to raise_exception(ToolException, "CPU.parse: invalid format")
			end

			it "raw metadata contains memories defined not as Hash" do
				dummy_raw = { :name => 'n', :memories => 'memories'}
				
				expect { CPU.parse dummy_raw }.to raise_exception(ToolException, "CPU.parse: memories for 'n' cpu defined in incorrect format")
			end

			it "raw metadata contains no information about memories" do
				dummy_raw = { :name => 'n' }
				
				expect { CPU.parse dummy_raw }.to raise_exception(ToolException, "CPU.parse: 'n' cpu has no memories defined")
			end
		end

		describe "parses correct cpu structure when" do
			it "it is passed a valid cpu name as string" do
				expect(CPU).to receive(:parse_names).with('name').and_return('a')
				expect(CPU).to receive(:find_cpu_metadata).with('a').and_return( { :name => 'n', :memories => { 1 => 2 } })
				expect(MemoryManager).to receive(:parse).with( { 1 => 2 } ).and_return([])

				parsed_cpu = CPU.parse 'name'

				parsed_cpu.name.should be == "n"
				parsed_cpu.memories.should be == []
			end
			
			it "it is passed a valid cpu alias" do
				dummy_raw = { :name => 'n', :memories => {'memories' => nil}}
				expect(MemoryManager).to receive(:parse).with({'memories' => nil}).and_return('a')

				parsed_cpu = CPU.parse dummy_raw

				parsed_cpu.name.should be == "n"
				parsed_cpu.memories.should be == 'a'
			end
		end
	end

	it "when mounting hex should mount" do
		cpu = CPU.new 'cpu'
		dummy_memories = {}
		cpu.memories = dummy_memories
		expect(HexFile).to receive(:parse).with('lines').and_yield(1, 2)
		expect(dummy_memories).to receive(:write_byte).with(1, 2)
		
		cpu.mount_hex 'lines'
	end

	it "when dumping hex should delegate work the HexFile.encode with properly formed raw_blocks" do
		cpu = CPU.new 'cpu'
		dummy_memories = [ Memory.new( 'a', 0, 10, 1 ), Memory.new( 'b', 20, 50, 2 ) ]
		dummy_memories[0].contents = [ 1, 2 ]
		dummy_memories[1].contents = [ 3, 4 ]
		dummy_memory_manager = {}
		cpu.memories = dummy_memory_manager
		expect(dummy_memory_manager).to receive(:memories).and_return(dummy_memories)
		expect(HexFile).to receive(:encode).with(
			{ 0 => {:start_address => 0, :contents => [1, 2] }, 
			  1 => {:start_address => 20, :contents => [3, 4] },
			}).and_return("result")
		
		cpu.dump_hex.should be == "result"
	end
end
