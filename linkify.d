import std.algorithm.searching;
import std.conv;
import std.file;
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

	foreach (line; stdin.byLine)
	{
		if (auto m = line.matchFirst(re!`, label=("[^"]*")];$`))
		{
			auto label = m[1].parseDotStr.splitLines();
			const(char)[] fn = label[0];
			auto lineNumber = label[1].findSplit(":")[0].to!int;

			string tooltip = null;
			if (fn.exists && lineNumber)
				tooltip = fn.readText.splitLines[lineNumber - 1];
			if (!lineNumber)
				label[1] = "(module)";

			const(char)[] url = null;

			if (auto p = fn.matchFirst(re!`/phobos/`))
			{
				fn = p.post;
				url = "https://github.com/dlang/phobos/blob/" ~ phobosVer ~ "/" ~ fn;
			}
			else
			if (auto p = fn.matchFirst(re!`/druntime/(src|import)/`))
			{
				fn = p.post;
				url = "https://github.com/dlang/druntime/blob/" ~ druntimeVer ~ "/src/" ~ fn;
			}

			if (url && lineNumber)
				url ~= "#L" ~ lineNumber.text;

			line = m.pre;
			line ~= ", label=" ~ ([fn.idup] ~ label[1..$]).join("\n").toDotStr();
			if (url)
				line ~= ", URL=" ~ url.toDotStr;
			if (tooltip)
				line ~= ", tooltip=" ~ tooltip.toDotStr;
			line ~= "];";
		}
		writeln(line);
	}
}

string parseDotStr(in char[] s) { return s.parseJSON.str; }
string toDotStr(in char[] s) { auto j = JSONValue(s); return toJSON(j, false, JSONOptions.doNotEscapeSlashes); }

Regex!char re(string pattern, alias flags = [])()
{
	static Regex!char r;
	if (r.empty)
		r = regex(pattern, flags);
	return r;
}
