## Description
A simple text based record database.

## Examples

### Example 1
```d
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

	TextRecords!NameData collector;
	collector.parse(data);
	auto records = collector.getRecordsRaw();

   	assert(records.front.firstName == "Albert");
    assert(records.back.firstName == "Albert");
    assert(records.length == 3);
    assert(records[0].firstName == "Albert");

    assert(collector.front.firstName == "Albert");
    assert(collector.back.firstName == "Albert");
   	assert(collector.length == 3);
    assert(collector[0].firstName == "Albert");
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
```

### Example 2
```d
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

	auto variedRecords = variedCollector.getRecordsRaw();
	variedCollector.dump();

	// Example using std.algorithm.
	immutable bool canFindValue = canFind!((VariedData data, size_t id) => data.id == id)(variedCollector[], 100);
	assert(canFindValue == true);

	//Sugar. Each struct member will generate a method named findAllBy<member name first letter capitalized>.
	assert(variedCollector.findAllById(100).length == 3);

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

	auto usingNamedMethod = variedCollector.findById(111);
	assert(usingNamedMethod[0].name == "Utada Hikaru");

	variedCollector.save("varied.db");
```

### Example 3
```d
	immutable string irrData =
	q{
		{
			nickName "Lisa"
			realName "Melissa"
			id "100"
		}

		{
			nickName "Liz"
			realName "Elizabeth Rogers"
			id "122"
		}
		{
			nickName "hikki"
			realName "Utada Hikaru"
			id "100"
		}
	};

	struct IrregularNames
	{
		string realName;
		string nickName;
		size_t id;
	}

	TextRecords!IrregularNames irrCollector;
	irrCollector.parse(irrData);

	//Sugar.
	auto idRecords = irrCollector.findAllById(100);
	assert(idRecords[1].realName == "Utada Hikaru");

	//More sugar.
	auto nickNameRecords = irrCollector.findAllByNickName("hikki");
	assert(nickNameRecords[0].realName == "Utada Hikaru");
```
