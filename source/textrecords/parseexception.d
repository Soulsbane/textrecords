module textrecords.parseexception;

import std.exception;
import std.stdio;
import std.conv;

class TextRecordsParseException : Exception
{
public:
	this(string msg, string file =__FILE__, size_t line = __LINE__, Throwable next = null) //@safe pure nothrow
	{
		writeln(msg ~ " in ", file ~ " near line ", line.to!string);
		super(msg, file, line, next);
	}
}
