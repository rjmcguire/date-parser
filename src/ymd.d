version (dateparser_test) import std.stdio;
import std.traits;
import std.conv;
import std.range.primitives;

import timelexer;

package struct YMD(R) if (isForwardRange!R && is(ElementEncodingType!R : const char))
{
private:
    bool century_specified = false;
    int[3] data;
    int dataPosition;
    R tzstr;

public:
    this(R tzstr)
    {
        this.tzstr = tzstr;
    }

    /**
     * Params
     */
    static bool couldBeYear(Range, N)(Range token, N year) if (isInputRange!Range
            && isSomeChar!(ElementEncodingType!Range) && is(NumericTypeOf!N : int))
    {
        import std.uni : isNumber;
        import std.exception : assumeWontThrow;

        if (token.front.isNumber)
        {
            return assumeWontThrow(to!int(token)) == year;
        }
        else
        {
            return false;
        }
    }

    /**
     * Attempt to deduce if a pre 100 year was lost due to padded zeros being
     * taken off
     *
     * Params:
     *     tokens = a range of tokens
     * Returns:
     *     the index of the year token. If no probable result was found, then -1
     *     is returned
     */
    int probableYearIndex(Range)(Range tokens) const if (isInputRange!Range
            && isNarrowString!(ElementType!(Range)))
    {
        import std.algorithm.iteration : filter;
        import std.range : walkLength;

        foreach (int index, ref token; data[])
        {
            auto potentialYearTokens = tokens.filter!(a => YMD.couldBeYear(a, token));
            immutable frontLength = potentialYearTokens.front.length;
            immutable length = potentialYearTokens.walkLength(3);

            if (length == 1 && frontLength > 2)
            {
                return index;
            }
        }

        return -1;
    }

    /// Put a value in that represents a year, month, or day
    void put(N)(N val) if (isNumeric!N)
    in
    {
        assert(dataPosition <= 3);
    }
    body
    {
        static if (is(N : int))
        {
            if (val > 100)
            {
                this.century_specified = true;
            }

            data[dataPosition] = val;
            ++dataPosition;
        }
        else
        {
            put(cast(int) val);
        }
    }

    /// ditto
    void put(S)(const S val) if (isSomeString!S)
    in
    {
        assert(dataPosition <= 3);
    }
    body
    {
        data[dataPosition] = to!int(val);
        ++dataPosition;

        if (val.length > 2)
        {
            this.century_specified = true;
        }
    }

    /// length getter
    size_t length() @property const @safe pure nothrow @nogc
    {
        return dataPosition;
    }

    /// century_specified getter
    bool centurySpecified() @property const @safe pure nothrow @nogc
    {
        return century_specified;
    }

    /**
     * Turns the array of ints into a `Tuple` of three, representing the year,
     * month, and day.
     *
     * Params:
     *     mstridx = The index of the month in the data
     *     yearfirst = if the year is first in the string
     *     dayfirst = if the day is first in the string
     * Returns:
     *     tuple of three ints
     */
    auto resolveYMD(N)(N mstridx, bool yearfirst, bool dayfirst) if (is(NumericTypeOf!N : size_t))
    {
        import std.algorithm.mutation : remove;
        import std.typecons : tuple;

        int year = -1;
        int month;
        int day;

        if (dataPosition == 1 || (mstridx != -1 && dataPosition == 2)) //One member, or two members with a month string
        {
            if (mstridx != -1)
            {
                month = data[mstridx];
                switch (mstridx)
                {
                    case 0:
                        data[0] = data[1];
                        data[1] = data[2];
                        data[2] = 0;
                        break;
                    case 1:
                        data[1] = data[2];
                        data[2] = 0;
                        break;
                    case 2:
                        data[2] = 0;
                        break;
                    default: break;
                }                
            }

            if (dataPosition > 1 || mstridx == -1)
            {
                if (data[0] > 31)
                {
                    year = data[0];
                }
                else
                {
                    day = data[0];
                }
            }
        }
        else if (dataPosition == 2) //Two members with numbers
        {
            if (data[0] > 31)
            {
                //99-01
                year = data[0];
                month = data[1];
            }
            else if (data[1] > 31)
            {
                //01-99
                month = data[0];
                year = data[1];
            }
            else if (dayfirst && data[1] <= 12)
            {
                //13-01
                day = data[0];
                month = data[1];
            }
            else
            {
                //01-13
                month = data[0];
                day = data[1];
            }

        }
        else if (dataPosition == 3) //Three members
        {
            if (mstridx == 0)
            {
                month = data[0];
                day = data[1];
                year = data[2];
            }
            else if (mstridx == 1)
            {
                if (data[0] > 31 || (yearfirst && data[2] <= 31))
                {
                    //99-Jan-01
                    year = data[0];
                    month = data[1];
                    day = data[2];
                }
                else
                {
                    //01-Jan-01
                    //Give precendence to day-first, since
                    //two-digit years is usually hand-written.
                    day = data[0];
                    month = data[1];
                    year = data[2];
                }
            }
            else if (mstridx == 2)
            {
                if (data[1] > 31)
                {
                    //01-99-Jan
                    day = data[0];
                    year = data[1];
                    month = data[2];
                }
                else
                {
                    //99-01-Jan
                    year = data[0];
                    day = data[1];
                    month = data[2];
                }
            }
            else
            {
                if (data[0] > 31 || probableYearIndex(tzstr.timeLexer) == 0
                        || (yearfirst && data[1] <= 12 && data[2] <= 31))
                {
                    //99-01-01
                    year = data[0];
                    month = data[1];
                    day = data[2];
                }
                else if (data[0] > 12 || (dayfirst && data[1] <= 12))
                {
                    //13-01-01
                    day = data[0];
                    month = data[1];
                    year = data[2];
                }
                else
                {
                    //01-13-01
                    month = data[0];
                    day = data[1];
                    year = data[2];
                }
            }
        }

        return tuple(year, month, day);
    }
}
