module textrecords.textrecords;

import std.stdio;
import std.conv : to;
import std.container : Array;
import std.string : removechars, lineSplitter;
import std.regex : Regex, ctRegex, matchFirst;
import std.algorithm;

private auto RECORD_FIELD_REGEX = ctRegex!(`\s+(?P<key>\w+)\s{1,1}(?P<value>.*)`);

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

	void save(const string name)
	{
		foreach(record; recordArray_)
		{
			writeln("{");

			foreach(memberName; allMembers!T)
			{
				immutable string code = "\t" ~ memberName ~ " " ~ "\"" ~ mixin("to!string(record." ~ memberName ~ ")") ~ "\"";
				writeln(code);
			}

			writeln("}\n");
		}
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

	RecordArray findAll(S)(const S value, const string recordField)
	{
		RecordArray foundRecords;

		foreach(memberName; allMembers!T)
		{
			if(memberName == recordField)
			{
				foreach(record; recordArray_)
				{
					auto dataName = mixin("record." ~ memberName);

					static if(is(typeof(dataName) == S))
					{
						if(dataName == value)
						{
							foundRecords.insert(record);
						}
					}
				}
			}
		}

		return foundRecords;
	}

	bool hasValue(S)(const S value, const string recordField)
	{
		foreach(memberName; allMembers!T)
		{
			if(memberName == recordField)
			{
<<<<<<< HEAD
				foreach(record; recordArray_)
				{
					auto dataName = mixin("record." ~ memberName);

					static if(is(typeof(dataName) == S))
					{
						if(dataName == value)
						{
							return true;
						}
					}
				}
=======
>>>>>>> 0ec124e6596720b7f6179addfd2fc5e41b284d9b
			}
		}

		return false;
	}

	RecordArray recordArray_;
	alias recordArray_ this;
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

	collector.dump();
	writeln;

	writeln("Testing findAll...found these records:");
	auto foundRecords = collector.findAll!string("Albert", "firstName");

	foreach(foundRecord; foundRecords)
	{
		writeln(foundRecord);
	}

	bool found = collector.hasValue!string("Albert", "firstName");
	bool notFound = collector.hasValue!string("Tom", "firstName");
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
	};

	enum fileName = "test-record.dat";

	struct VariedData
	{
		string name;
		size_t id;
	}

	TextRecords!VariedData variedCollector;

	variedCollector.parse(variedData);
	assert(variedCollector.length == 3);
	//variedCollector.parseFile(variedData); // FIXME: Add temporary file.

	auto variedFoundRecords = variedCollector.findAll!size_t(100, "id");
	assert(variedFoundRecords.length == 2);

	auto variedRecords = variedCollector.getRecords();
	variedCollector.dump();

	//return canFind!((T data, string text) => mixin("data." ~ memberName) == text)(recordArray_[], value);

}
