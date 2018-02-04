import std.algorithm.searching;
import std.conv;
import std.file : readText, exists;
import std.stdio;
import std.string;

/// Print longest chain in a profile.json

import ae.utils.funopt;
import ae.utils.json;
import ae.utils.main;

void longest(string profileJson)
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
	int[] longestCallchain;
	foreach (event; profile.events)
		if (longestCallchain.length < event.callchain.length)
			longestCallchain = event.callchain;

	foreach (f; longestCallchain)
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