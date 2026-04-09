using System.Collections;
using System.Collections.Generic;
using System.Text;

namespace Abzora.TryOn
{
    public static class MiniJson
    {
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
                    builder.Append(value);
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
    }
}
