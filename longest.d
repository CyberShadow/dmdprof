import std.algorithm.iteration;
import std.algorithm.searching;
import std.conv;
import std.file : readText, exists;
import std.range.primitives;
import std.stdio;
import std.string;

/// Print longest chain in a profile.json

import ae.utils.funopt;
import ae.utils.json;
import ae.utils.main;

void longest(string profileJson, bool countModules, string including = null)
{
	@JSONPartial
	struct Profile
	{
		struct Function
		{
			@JSONName("module") string fileName;
			@JSONName("name") string pos;
		}
		Function[] functions;

		struct Event
		{
			int[] callchain;
			float[] cost;
		}
		Event[] events;
	}

	Profile profile = profileJson.readText.jsonParse!Profile;
	int[] bestCallchain; size_t bestLength;

	foreach (event; profile.events)
	{
		bool ok;
		if (including)
		{
			foreach (f; event.callchain)
				if (profile.functions[f].fileName.canFind(including))
					ok = true;
		}
		else
			ok = true;
		if (!ok)
			continue;

		size_t length;
		if (countModules)
			length = event.callchain.map!(f => profile.functions[f].fileName).uniq.walkLength;
		else
			length = event.callchain.length;

		if (bestLength < length)
		{
			bestCallchain = event.callchain;
			bestLength = length;
		}
	}

	foreach (f; bestCallchain)
	{
		auto fn = profile.functions[f].fileName;
		write(fn);
		auto line = profile.functions[f].pos.findSplit(":")[0].to!int;
		if (line)
			write("(", profile.functions[f].pos, ")");
		if (line && fn.exists)
			write(":", fn.readText.splitLines[line-1]);
		writeln;
	}
}

mixin main!(funopt!longest);
