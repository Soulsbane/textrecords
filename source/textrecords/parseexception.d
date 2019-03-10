module textrecords.parseexception;

import std.exception;

class TextRecordsParseException : Exception
{
public:
	this(string msg, string file =__FILE__, size_t line = __LINE__, Throwable next = null) @safe pure nothrow
	{
		super("TextRecordsParseException: " ~ msg, file, line, next);
	}
}
