using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace Abzora.TryOn
{
    public static class MiniJson
    {
        public static object Deserialize(string json)
        {
            if (string.IsNullOrEmpty(json))
            {
                return null;
            }

            return Parser.Parse(json);
        }

        public static string Serialize(object value)
        {
            var builder = new StringBuilder(256);
            WriteValue(builder, value);
            return builder.ToString();
        }

        private static void WriteValue(StringBuilder builder, object value)
        {
            switch (value)
            {
                case null:
                    builder.Append("null");
                    break;
                case string stringValue:
                    builder.Append('"').Append(stringValue.Replace("\"", "\\\"")).Append('"');
                    break;
                case bool boolValue:
                    builder.Append(boolValue ? "true" : "false");
                    break;
                case IDictionary dictionary:
                    WriteDictionary(builder, dictionary);
                    break;
                case IEnumerable enumerable:
                    WriteArray(builder, enumerable);
                    break;
                default:
                    if (value is float || value is double || value is decimal)
                    {
                        builder.AppendFormat(CultureInfo.InvariantCulture, "{0}", value);
                    }
                    else
                    {
                        builder.Append(value);
                    }
                    break;
            }
        }

        private static void WriteDictionary(StringBuilder builder, IDictionary dictionary)
        {
            builder.Append('{');
            var first = true;
            foreach (DictionaryEntry entry in dictionary)
            {
                if (!first)
                {
                    builder.Append(',');
                }
                first = false;
                WriteValue(builder, entry.Key.ToString());
                builder.Append(':');
                WriteValue(builder, entry.Value);
            }
            builder.Append('}');
        }

        private static void WriteArray(StringBuilder builder, IEnumerable enumerable)
        {
            builder.Append('[');
            var first = true;
            foreach (var item in enumerable)
            {
                if (!first)
                {
                    builder.Append(',');
                }
                first = false;
                WriteValue(builder, item);
            }
            builder.Append(']');
        }

        private sealed class Parser : System.IDisposable
        {
            private enum Token
            {
                None,
                CurlyOpen,
                CurlyClose,
                SquaredOpen,
                SquaredClose,
                Colon,
                Comma,
                String,
                Number,
                True,
                False,
                Null
            }

            private readonly StringReader _json;

            private Parser(string json)
            {
                _json = new StringReader(json);
            }

            public static object Parse(string json)
            {
                using (var instance = new Parser(json))
                {
                    return instance.ParseValue();
                }
            }

            public void Dispose()
            {
                _json.Dispose();
            }

            private IDictionary<string, object> ParseObject()
            {
                var table = new Dictionary<string, object>();
                _json.Read();

                while (true)
                {
                    switch (NextToken)
                    {
                        case Token.None:
                            return null;
                        case Token.Comma:
                            continue;
                        case Token.CurlyClose:
                            return table;
                        default:
                            var name = ParseString();
                            if (name == null)
                            {
                                return null;
                            }

                            if (NextToken != Token.Colon)
                            {
                                return null;
                            }
                            _json.Read();

                            table[name] = ParseValue();
                            break;
                    }
                }
            }

            private IList<object> ParseArray()
            {
                var array = new List<object>();
                _json.Read();

                var parsing = true;
                while (parsing)
                {
                    var nextToken = NextToken;
                    switch (nextToken)
                    {
                        case Token.None:
                            return null;
                        case Token.Comma:
                            continue;
                        case Token.SquaredClose:
                            parsing = false;
                            break;
                        default:
                            array.Add(ParseByToken(nextToken));
                            break;
                    }
                }

                return array;
            }

            private object ParseValue()
            {
                return ParseByToken(NextToken);
            }

            private object ParseByToken(Token token)
            {
                switch (token)
                {
                    case Token.String:
                        return ParseString();
                    case Token.Number:
                        return ParseNumber();
                    case Token.CurlyOpen:
                        return ParseObject();
                    case Token.SquaredOpen:
                        return ParseArray();
                    case Token.True:
                        return true;
                    case Token.False:
                        return false;
                    case Token.Null:
                        return null;
                    default:
                        return null;
                }
            }

            private string ParseString()
            {
                var builder = new StringBuilder();
                _json.Read();

                var parsing = true;
                while (parsing)
                {
                    if (_json.Peek() == -1)
                    {
                        break;
                    }

                    var c = NextChar;
                    switch (c)
                    {
                        case '"':
                            parsing = false;
                            break;
                        case '\\':
                            if (_json.Peek() == -1)
                            {
                                parsing = false;
                                break;
                            }

                            c = NextChar;
                            switch (c)
                            {
                                case '"':
                                case '\\':
                                case '/':
                                    builder.Append(c);
                                    break;
                                case 'b':
                                    builder.Append('\b');
                                    break;
                                case 'f':
                                    builder.Append('\f');
                                    break;
                                case 'n':
                                    builder.Append('\n');
                                    break;
                                case 'r':
                                    builder.Append('\r');
                                    break;
                                case 't':
                                    builder.Append('\t');
                                    break;
                                case 'u':
                                    var hex = new char[4];
                                    for (var i = 0; i < 4; i++)
                                    {
                                        hex[i] = NextChar;
                                    }
                                    builder.Append((char)int.Parse(new string(hex), NumberStyles.HexNumber));
                                    break;
                            }
                            break;
                        default:
                            builder.Append(c);
                            break;
                    }
                }

                return builder.ToString();
            }

            private object ParseNumber()
            {
                var number = NextWord;
                if (number.IndexOf('.') == -1)
                {
                    if (long.TryParse(number, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsedInt))
                    {
                        return parsedInt;
                    }
                }

                if (double.TryParse(number, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsedDouble))
                {
                    return parsedDouble;
                }
                return 0d;
            }

            private void EatWhitespace()
            {
                while (_json.Peek() != -1 && char.IsWhiteSpace(PeekChar))
                {
                    _json.Read();
                }
            }

            private char PeekChar => Convert.ToChar(_json.Peek());

            private char NextChar => Convert.ToChar(_json.Read());

            private string NextWord
            {
                get
                {
                    var builder = new StringBuilder();
                    while (_json.Peek() != -1 && !IsWordBreak(PeekChar))
                    {
                        builder.Append(NextChar);
                    }

                    return builder.ToString();
                }
            }

            private Token NextToken
            {
                get
                {
                    EatWhitespace();
                    if (_json.Peek() == -1)
                    {
                        return Token.None;
                    }

                    var c = PeekChar;
                    switch (c)
                    {
                        case '{':
                            return Token.CurlyOpen;
                        case '}':
                            _json.Read();
                            return Token.CurlyClose;
                        case '[':
                            return Token.SquaredOpen;
                        case ']':
                            _json.Read();
                            return Token.SquaredClose;
                        case ',':
                            _json.Read();
                            return Token.Comma;
                        case '"':
                            return Token.String;
                        case ':':
                            return Token.Colon;
                        case '-':
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9':
                            return Token.Number;
                    }

                    var word = NextWord;
                    if (word == "false")
                    {
                        return Token.False;
                    }
                    if (word == "true")
                    {
                        return Token.True;
                    }
                    if (word == "null")
                    {
                        return Token.Null;
                    }
                    return Token.None;
                }
            }

            private static bool IsWordBreak(char c)
            {
                return char.IsWhiteSpace(c) ||
                       c == ',' ||
                       c == ':' ||
                       c == ']' ||
                       c == '}' ||
                       c == '[' ||
                       c == '{' ||
                       c == '"';
            }
        }
    }
}
