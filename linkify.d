import std.algorithm.searching;
import std.getopt;
import std.json;
import std.regex;
import std.stdio;
import std.string;

void main(string[] args)
{
	string phobosVer = "master", druntimeVer = "master";
	getopt(args,
		"phobos", "Phobos version in URLs", &phobosVer,
		"druntime", "Druntime version in URLs", &druntimeVer,
	);

	auto r = regex(`, label=("[^"]*")];$`);
	foreach (line; stdin.byLine)
	{
		if (auto m = line.matchFirst(r))
		{
			auto label = m[1].parseJSON.str.splitLines();
			auto fn = label[0];
			auto lineNumber = label[1].findSplit(":")[0];
			string url = null;
			if (fn == "object.d" || fn.startsWith("core/"))
				url = "https://github.com/dlang/druntime/blob/src/" ~ druntimeVer ~ "/" ~ fn ~ "#L" ~ lineNumber;
			else
			if (fn.startsWith("std/") || fn.startsWith("etc/"))
				url = "https://github.com/dlang/phobos/blob/" ~ phobosVer ~ "/" ~ fn ~ "#L" ~ lineNumber;
			if (url)
			{
				auto j = JSONValue(url);
				line = line[0..$-2] ~ ", URL=" ~ toJSON(j, false, JSONOptions.doNotEscapeSlashes ) ~ "];";
			}
		}
		writeln(line);
	}
}
