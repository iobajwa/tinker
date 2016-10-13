
require "spec_helper"
require "tinker"
require "helpers/tool_messages"
require "helpers/variable"

describe Tinker do
	before(:each) do
		$tinker = Tinker.new "image"
		$tinker.variables = [ Variable.new("volts", 2, 'u16', 0, 230, "eeprom"), 
		                     Variable.new("amps", 2, 'u16', 0, 10, "flash"), ]
		$dummy_cpu = []
		$tinker.cpu = $dummy_cpu
	end
	
	describe "when obtaining a variable instance" do
		it "should raise exception when no matching variable is found" do
			expect { $tinker.get_variable "blah" }.to raise_exception(ToolException, "Tinker: variable not found ('blah')" )
		end
		it "should return the matching instance otherwise" do
			$tinker.get_variable("AMPS").should be == $tinker.variables[1]
		end
	end

	describe "when reading variable value using index" do
		it "should return correct value as read from cpu" do
			dummy_var      = $tinker.variables[1]
			dummy_memories = { 1 => 2}
			dummy_memory   = { 3 => 4 }
			expect($tinker).to receive(:get_variable).with("v").and_return(dummy_var)
			expect($dummy_cpu).to receive(:memories).and_return(dummy_memories)
			expect(dummy_memories).to receive(:[]).with("flash").and_return(dummy_memory)
			expect(dummy_memory).to receive(:read_object).with( 0, 2 ).and_return('result')
			expect(dummy_var).to receive(:deserialize).with("result").and_return(["result"])
			
			$tinker["v"].should be == ['result']
		end
		it "should raise exception with description when underlying call failed with an exception" do
			expect($tinker).to receive(:get_variable).with("v").and_return($tinker.variables[1])
			expect($dummy_cpu).to receive(:memories).and_raise(ToolException, "blah blah blah")

			expect { $tinker["v"] }.to raise_exception(ToolException, "Tinker: error reading variable 'amps': blah blah blah")
		end
	end

	describe "when writing variable value using index" do
		it "should delgate work to cpu with proper information" do
			dummy_var = $tinker.variables[1]
			dummy_memories = { 1 => 2}
			dummy_memory   = { 3 => 4 }
			expect($tinker).to receive(:get_variable).with("v").and_return(dummy_var)
			expect(dummy_var).to receive(:serialize).with(12).and_return([12])
			expect($dummy_cpu).to receive(:memories).and_return(dummy_memories)
			expect(dummy_memories).to receive(:[]).with("flash").and_return(dummy_memory)
			expect(dummy_memory).to receive(:write_object).with([12], 0)
			
			$tinker["v"] = 12
		end
		it "should raise exception with description when underlying call failed with an exception" do
			expect($tinker).to receive(:get_variable).with("v").and_return($tinker.variables[1])
			expect($dummy_cpu).to receive(:memories).and_raise(ToolException, "blah blah blah")

			expect { $tinker["v"] = 12 }.to raise_exception(ToolException, "Tinker: error writing variable 'amps': blah blah blah")
		end
	end


	describe "when loading image" do
		describe "should raise exception when" do
			it "hex_file does not exists" do
				expect(File).to receive(:exists?).with('hex').and_return(false)
				expect { Tinker.load_image 'hex', 'meta.file' }.to raise_exception(ToolException, "Tinker: hex file ('hex') does not exists")
			end
			it "meta_file does not exists" do
				expect(File).to receive(:exists?).with('hex').and_return(true)
				expect(File).to receive(:exists?).with('meta.file').and_return(false)
				expect { Tinker.load_image 'hex', 'meta.file' }.to raise_exception(ToolException, "Tinker: meta file ('meta.file') does not exists")
			end
		end
		it "returns a tinker instance when a meta_file is provided" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('file.hex').and_return(true)
			expect(File).to receive(:exists?).with('meta.file').and_return(true)
			expect(YAML).to receive(:load_file).with('meta.file').and_return({:meta => { :cpu => 'cpu', :data => dummy_data } })
			expect(Variable).to receive(:parse).with(1, 2).and_return('var 1')
			expect(Variable).to receive(:parse).with(3, 4).and_return('var 2')
			expect(File).to receive(:readlines).with('file.hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).with('file').and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with(['var 1', 'var 2'])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('file.hex')
			expect(dummy_tinker_object).to receive(:meta_file=).with('meta.file')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('file.hex', 'meta.file').should be == dummy_tinker_object
		end
		it "returns a tinker instance when a cpu name is provided" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('hex').and_return(true)
			expect(File).to receive(:readlines).with('hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with([])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('hex')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('hex', 'cpu').should be == dummy_tinker_object
		end
		it "returns a tinker instance when hash as meta_file is provided" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('hex').and_return(true)
			expect(Variable).to receive(:parse).with(1, 2).and_return('var 1')
			expect(Variable).to receive(:parse).with(3, 4).and_return('var 2')
			expect(File).to receive(:readlines).with('hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with(['var 1', 'var 2'])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('hex')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('hex', {:meta => { :cpu => 'cpu', :data => dummy_data } }).should be == dummy_tinker_object
		end
	end

	it "when writing default values of variables, writes values of each variable" do
		a = []
		b = []
		expect($tinker).to receive(:variables).and_return([a, b])
		expect(a).to receive(:default_value).and_return('1')
		expect(b).to receive(:default_value).and_return('2')
		expect($tinker).to receive(:write_value_object).with(a, '1')
		expect($tinker).to receive(:write_value_object).with(b, '2')

		$tinker.write_default_values
	end

	describe "when dumping loaded image to a file" do
		it "creates valid file contents" do
			expect($dummy_cpu).to receive(:dump_hex).and_return("lines")
			dummy_file = double("dummy file").as_null_object
			expect(dummy_file).to receive(:puts).with("lines")
			expect(dummy_file).to receive(:close)
			expect(File).to receive(:new).with("blah", "w").and_return(dummy_file)

			$tinker.dump "blah"
		end

		it "makes sure the file is closed when an exception is encountered" do
			expect($dummy_cpu).to receive(:dump_hex).and_return("lines")
			expect(File).to receive(:new).with("blah", "w").and_raise("blaah")

			expect { $tinker.dump "blah" }.to raise_exception("blaah")
		end
	end

	describe "when performing a diff" do
		describe "and safe-loading an image" do
			it "returns passed object ref as-is when an Tinker object is passed" do
				t = Tinker.new 't'
				returned = Tinker.safe_load_image_file t, 'meta'
				returned.should be == t
			end
			it "returns a tinker instance when passed image is file-name" do
				t = Tinker.new 't'
				expect(Tinker).to receive(:load_image).with('file.hex', 'meta').and_return('result')
				returned = Tinker.safe_load_image_file 'file.hex', 'meta'
				returned.should be == "result"
			end
		end
		
		it "on memory count, returns correct results" do
			dummy_memory1 = double('1').as_null_object
			dummy_memory2 = double('2').as_null_object
			dummy_memory3 = double('3').as_null_object
			dummy_memory4 = double('4').as_null_object
			base_memories  = [ dummy_memory1, dummy_memory2 ]
			other_memories = [ dummy_memory3, dummy_memory4 ]
			expect(dummy_memory1).to receive(:name).and_return('1')
			expect(dummy_memory2).to receive(:name).and_return('2')
			expect(dummy_memory3).to receive(:name).and_return('3')
			expect(dummy_memory4).to receive(:name).and_return('4')
			expect(dummy_memory1).to receive(:size).and_return(1)
			expect(dummy_memory2).to receive(:size).and_return(2)
			expect(dummy_memory3).to receive(:size).and_return(3)
			expect(dummy_memory4).to receive(:size).and_return(4)
			expect(other_memories).to receive(:get_memory).with('1').and_return('a')
			expect(other_memories).to receive(:get_memory).with('2').and_return('a')
			expect(MemoryDiff).to receive(:valid_hit?).with('1', 1, dummy_memory1, 'a').and_return(:one)
			expect(MemoryDiff).to receive(:valid_hit?).with('2', 2, dummy_memory2, 'a').and_return(nil)
			expect(base_memories).to receive(:get_memory).with('3').and_return('b')
			expect(base_memories).to receive(:get_memory).with('4').and_return('b')
			expect(MemoryDiff).to receive(:valid_hit?).with('3', 3, 'b', dummy_memory3).and_return(nil)
			expect(MemoryDiff).to receive(:valid_hit?).with('4', 4, 'b', dummy_memory4).and_return(:two)

			Tinker.perform_memory_count_diff( base_memories, other_memories ).should be == [:one, :two]
		end

		it "on memory cells, returns correct results" do
			base_memory1 = Memory.new 'base_memory1', 0, 10, 1
			base_memory2 = Memory.new 'base_memory2', 10, 10, 1
			other_memory1 = Memory.new 'other_memory1', 0, 10, 1
			base_memories = [ base_memory1, base_memory2 ]
			other_memories = double('other_memories').as_null_object
			expect(other_memories).to receive(:get_memory).with('base_memory1').and_return(nil)
			expect(other_memories).to receive(:get_memory).with('base_memory2').and_return(other_memory1)
			base_memory2.contents = [1, 2]
			other_memory1.contents = [3, 4]
			expect(base_memory2).to receive(:index_to_address).with(0).and_return(-1)
			expect(other_memory1).to receive(:index_to_address).with(0).and_return('address 1')
			expect(MemoryCellDiff).to receive(:valid_hit?).with('base_memory2', 10, 'address 1', 1, 3).and_return(nil)
			expect(base_memory2).to receive(:index_to_address).with(1).and_return(2000)
			diff_result = DiffResult.new 'memory_name', 20, 'diff_type'
			expect(MemoryCellDiff).to receive(:valid_hit?).with('base_memory2', 10, 2000, 2, 4).and_return(diff_result)

			Tinker.perform_memory_cell_diff('base_image', base_memories, other_memories ).should be == [diff_result]
			diff_result.base_name.should be == 'base_image'
		end

		it "should return valid results" do
			dummy_base_image = []
			dummy_other_image = []
			base_memories  = []
			other_memories = []
			dummy_cpu1 = []
			dummy_cpu2 = []
			expect(Tinker).to receive(:safe_load_image_file).with('base_file', 'meta_file').and_return(dummy_base_image)
			expect(Tinker).to receive(:safe_load_image_file).with('other_file', 'meta_file').and_return(dummy_other_image)
			expect(dummy_base_image).to receive(:cpu).and_return(dummy_cpu1)
			expect(dummy_other_image).to receive(:cpu).and_return(dummy_cpu2)
			expect(dummy_cpu1).to receive(:memories).and_return(base_memories)
			expect(dummy_cpu2).to receive(:memories).and_return(other_memories)
			expect(Tinker).to receive(:perform_memory_count_diff).with(base_memories, other_memories).and_return([1, 2])
			expect(dummy_base_image).to receive(:name).and_return('name')
			expect(Tinker).to receive(:perform_memory_cell_diff).with('name', base_memories, other_memories).and_return([3, 4])
			
			results = Tinker.diff 'base_file', 'other_file', 'meta_file'

			results.should be == [1, 2, 3, 4]
		end
	end
end
