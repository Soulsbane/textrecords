/**
	A simple record format processor.
*/
module textrecords.textrecords;

import std.stdio;
import std.conv : to;
import std.container : Array;
import std.string : removechars, lineSplitter;
import std.regex : Regex, ctRegex, matchFirst;
import std.algorithm;
import std.range;
import std.array;
import std.format;
import std.string;

private auto RECORD_FIELD_REGEX = ctRegex!(`\s+(?P<key>\w+)\s{1,1}(?P<value>.*)`);
alias StdFind = std.algorithm.searching.find;

private template allMembers(T)
{
	enum allMembers = __traits(allMembers, T);
}

/**
	Manages a record format.

	Example:
		--------------------------------------
		string records = "
			{
				firstName "Albert"
				lastName "Einstein"
			}

			{
				firstName "Grace"
				lastName "Hopper"
			}
		";

		struct SimpleRecord
		{
			string firstName;
			string lastName;
		}

		void main()
		{
			TextRecords!SimpleRecord collector;
			collector.parse(records);

			foreach(entry; collector.getRecords())
			{
				writeln(entry);
			}
		}
		--------------------------------------
*/
struct TextRecords(T)
{
	alias RecordArray = Array!T;
	alias StringArray = Array!string;

	/**
		Converts the record from a file to its corresponding struct T.

		Params:
			strArray = The array of lines that contains an actual record.

		Returns:
			A struct of type T filled with record values mapped to the struct members.

	*/
	private T convertToRecord(StringArray strArray)
	{
		T data;

		foreach(line; strArray)
		{
			auto re = matchFirst(line, RECORD_FIELD_REGEX);

			if(!re.empty)
			{
				immutable string key = re["key"].removechars("\"");
				immutable string value = re["value"].removechars("\"");

				foreach(field; allMembers!T)
				{
					if(field == key)
					{
						// This generates code in the form of: data.field=to!type(value);
						immutable string generatedCode = "data." ~ field ~ "=to!" ~ typeof(mixin("data." ~ field)).stringof ~ "(value);";
						mixin(generatedCode);
					}
				}
			}
		}

		return data;
	}

	/**
		Parses a string into an array of records.

		Params:
			records = The string of records to process.

		Returns:
			An $(LINK2 http://dlang.org/phobos/std_container_array.html, std.container.Array) of records.
	*/
	RecordArray parse(const string records)
	{
		import std.algorithm : canFind;
		auto lines = records.lineSplitter();

		StringArray strArray;

		foreach(line; lines)
		{
			if(line.canFind("{"))
			{
				strArray.clear();
			}
			else if(line.canFind("}"))
			{
				recordArray_.insert(convertToRecord(strArray));
			}
			else
			{
				strArray.insert(line);
			}
		}

		return recordArray_;
	}

	/**
		Loads a file of records and parses it.

		Params:
			fileName = The name of the file to parse.

		Returns:
			An $(LINK2 http://dlang.org/phobos/std_container_array.html, std.container.Array) of records.
	*/
	RecordArray parseFile(const string fileName)
	{
		import std.path : exists;
		import std.file : readText;

		RecordArray recArray;

		if(fileName.exists)
		{
			recArray = parse(fileName.readText);
		}

		return recArray;
	}

	/**
		Saves records to a file.

		Params:
			name = Name of the file to save records to.
	*/
	void save(const string name) //TODO: actually save to file; only outputs to stdout at the moment.
	{

		auto app = appender!string();
		auto f = File(name, "w");

		foreach(record; recordArray_)
		{
			app.put("{\n");

			foreach(memberName; allMembers!T)
			{
				immutable string code = "\t" ~ memberName ~ " " ~ "\"" ~ mixin("to!string(record." ~ memberName ~ ")") ~ "\"\n";
				app.put(code);
			}

			app.put("}\n\n");
		}

		f.write(app.data);
	}

	debug
	{
		/**
			Outputs each record to stdout. $(B This method is only available in debug build).
		*/
		void dump()
		{
			debug recordArray_.each!writeln;
		}
	}

	/**
		Returns an array of records.

		Returns:
			An array of records.
	*/
	auto getRecords()
	{
		return recordArray_;
	}

	auto find(S, alias recordField)(const S value, size_t amount = 1)
	{
		auto found = filter!((T data) => mixin("data." ~ recordField) == value)(recordArray_[]).array;

		if(amount != 0)
		{
			return found.take(amount);
		}

		return found;
	}

	auto findAll(S, alias recordField)(const S value)
	{
		return find!(S, recordField)(value, 0);
	}

	void remove(S, alias recordField)(const S value, size_t removeCount = 1)
	{
		auto found = StdFind!((T data, S fieldValue) => mixin("data." ~ recordField) == fieldValue)(recordArray_[], value);

		if(removeCount != 0)
		{
			recordArray_.linearRemove(found.take(removeCount));
		}
		else
		{
			recordArray_.linearRemove(found.take(found.length));
		}
	}

	void removeAll(S, alias recordField)(const S value)
	{
		remove!(S, recordField)(value, 0);
	}

	bool hasValue(S, alias recordField)(const S value)
	{
		return canFind!((T data) => mixin("data." ~ recordField) == value)(recordArray_[]);
	}

	void insert(T value)
	{
		recordArray_.insert(value);
	}

	mixin(generateInsertMethod!T);
	mixin(generateFindMethodNameCode!T);
	mixin(generateFindAllMethodNameCode!T);

	RecordArray recordArray_;
	alias recordArray_ this;
}

private string generateInsertMethod(T)()
{
	/*
	Generates an insert method where the parameters are each field of T
	For Example:

	struct NameData
	{
		string firstName;
		string lastName;
	}

	Will generate this function:

	void insert(string firstName, string lastName)
	{
		NameData data;

		data.firstName = firstName;
		data.lastName = lastName;

		insert(data);
	}
	*/
	string code;

	code = "void insert(";

	foreach (index, memberType; typeof(T.tupleof))
	{
		code ~= memberType.stringof ~ " " ~ T.tupleof[index].stringof ~ ", ";
	}

	if(code.back == ',')
	{
		code.popBack;
	}

	code ~= "){";
	code ~= "T data;";


	foreach (index, memberType; typeof(T.tupleof))
	{
		string memberName = T.tupleof[index].stringof;
		code ~= "data." ~  memberName ~ " = " ~ memberName ~ ";";
	}

	code ~= "insert(data);";
	code ~= "}";

	return code;
}

/*
	This generates an find method based on a structs member names. For example this struct:

	struct Test
	{
		string name;
	}

	will generate this code:

	void findName(const string value)
	{
		return find!(string, "name")(value);
	}

	it does this for each member of the struct.
*/
private string generateFindMethodNameCode(T)()
{
	string code;

	foreach (i, memberType; typeof(T.tupleof))
	{
		immutable string memType = memberType.stringof;

		code ~= format(q{
			auto find%s(const %s value)
			{
				return find!(%s, "%s")(value);
			}
		}, T.tupleof[i].stringof.capitalize, memType, memType, T.tupleof[i].stringof);
	}

	return code;
}

/*
	This generates an find method based on a structs member names. For example this struct:

	struct Test
	{
		string name;
	}

	will generate this code:

	void findNameAll(const string value)
	{
		return find!(string, "name")(value);
	}

	it does this for each member of the struct.
*/
private string generateFindAllMethodNameCode(T)()
{
	string code;

	foreach (i, memberType; typeof(T.tupleof))
	{
		immutable string memType = memberType.stringof;

		code ~= format(q{
			auto find%sAll(const %s value)
			{
				return find!(%s, "%s")(value, 0);
			}
		}, T.tupleof[i].stringof.capitalize, memType, memType, T.tupleof[i].stringof);
	}

	return code;
}

///
unittest
{
	import std.stdio : writeln;

	immutable string data =
	q{
		{
			firstName "Albert"
			lastName "Einstein"
		}

		{
			firstName "John"
			lastName "Doe"
		}

		{
			firstName "Albert"
			lastName "Einstein"
		}
	};

	struct NameData
	{
		string firstName;
		string lastName;
	}

	writeln("Processing records for NameData:");

	TextRecords!NameData collector;
	collector.parse(data);

	auto records = collector.getRecords();

	assert(records.front.firstName == "Albert");
	assert(records.back.firstName == "Albert");
	assert(records.length == 3);
	assert(records[0].firstName == "Albert");

	// Since TextRecords supports alias this we can also use collector directly without calling getRecords.
	assert(collector.front.firstName == "Albert");
	assert(collector.back.firstName == "Albert");
	assert(collector.length == 3);
	assert(collector[0].firstName == "Albert");

	collector.dump();
	writeln;

	writeln("Testing findAll...found these records:");
	auto foundRecords = collector.findAll!(string, "firstName")("Albert");

	foreach(foundRecord; foundRecords)
	{
		writeln(foundRecord);
	}

	bool found = collector.hasValue!(string, "firstName")("Albert");
	bool notFound = collector.hasValue!(string, "firstName")("Tom");
	assert(found == true);
	assert(notFound == false);

	writeln("Saving...");
	collector.save("test.data");

	writeln;
	writeln("Processing records for VariedData:");

	immutable string variedData =
	q{
		{
			name "Albert Einstein"
			id "100"
		}

		{
			name "George Washington"
			id "200"
		}

		{
			name "Takahashi Ohmura"
			id "100"
		}

		{
			name "Nakamoto Suzuka"
			id "100"
		}
	};

	enum fileName = "test-record.dat";

	struct VariedData
	{
		string name;
		size_t id;
	}

	TextRecords!VariedData variedCollector;

	variedCollector.parse(variedData);
	assert(variedCollector.length == 4);
	//variedCollector.parseFile(variedData); // FIXME: Add temporary file.

	auto variedFoundRecords = variedCollector.findAll!(size_t, "id")(100);
	assert(variedFoundRecords.length == 3);

	auto variedRecords = variedCollector.getRecords();
	variedCollector.dump();

	immutable bool canFindValue = canFind!((VariedData data, size_t id) => data.id == id)(variedCollector[], 100);
	assert(canFindValue == true);

	assert(variedCollector.findIdAll(100).length == 3);

	variedCollector.remove!(size_t, "id")(100);
	assert(variedCollector.length == 3);

	variedCollector.removeAll!(size_t, "id")(100);
	assert(variedCollector.length == 1);

	immutable bool canFindValueInvalid = canFind!((VariedData data, size_t id) => data.id == id)(variedCollector[], 999);
	assert(canFindValueInvalid == false);

	VariedData insertData;
	variedCollector.insert(insertData);
	assert(variedCollector.length == 2);

	variedCollector.insert("Utada Hikaru", 111);
	assert(variedCollector.length == 3);

	auto record = variedCollector.find!(size_t, "id")(111);
	assert(record[0].name == "Utada Hikaru");

	auto usingNamedMethod = variedCollector.findId(111);
	assert(usingNamedMethod[0].name == "Utada Hikaru");

	variedCollector.save("varied.db");
}
