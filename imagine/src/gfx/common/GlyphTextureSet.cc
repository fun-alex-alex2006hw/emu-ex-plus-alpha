/*  This file is part of Imagine.

	Imagine is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	Imagine is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Imagine.  If not, see <http://www.gnu.org/licenses/> */

#define LOGTAG "ResFace"

#include <imagine/util/bits.h>
#include <imagine/gfx/GlyphTextureSet.hh>
#include <imagine/logger/logger.h>
#include <imagine/mem/mem.h>

namespace Gfx
{

static const char firstDrawableAsciiChar = '!';
static const char lastDrawableAsciiChar = '~';
static const uint numDrawableAsciiChars = (lastDrawableAsciiChar - firstDrawableAsciiChar) + 1;

// definitions for the Unicode Basic Multilingual Plane (BMP)
static const uint unicodeBmpChars = 0xFFFE;

// location & size of the surrogate/private chars
static const uint unicodeBmpPrivateStart = 0xD800, unicodeBmpPrivateEnd = 0xF8FF;
static const uint unicodeBmpPrivateChars = 0x2100;

static const uint unicodeBmpUsedChars = unicodeBmpChars - unicodeBmpPrivateChars;

static const uint glyphTableEntries = GlyphTextureSet::supportsUnicode ? unicodeBmpUsedChars : numDrawableAsciiChars;

static std::errc mapCharToTable(uint c, uint &tableIdx);

class GfxGlyphImage : public GfxImageSource
{
public:
	GfxGlyphImage(IG::GlyphImage glyphBuff): lockBuff{std::move(glyphBuff)} {}

	std::errc write(IG::Pixmap out) final
	{
		auto src = lockBuff.pixmap();
		//logDMsg("copying char %dx%d, pitch %d to dest %dx%d, pitch %d", src.x, src.y, src.pitch, out.x, out.y, out.pitch);
		assert(src.w() != 0 && src.h() != 0 && src.pixel({}));
		if(Config::envIsAndroid && !src.pitchBytes()) // Hack for JXD S7300B which returns y = x, and pitch = 0
		{
			logWarn("invalid pitch returned for char bitmap");
			src = {{out.size(), out.format()}, src.pixel({}), {out.pitchBytes(), IG::Pixmap::BYTE_UNITS}};
		}
		out.write(src, {});
		return {};
	}

	IG::Pixmap lockPixmap() final
	{
		return lockBuff.pixmap();
	}

	void unlockPixmap() final
	{
		lockBuff.unlock();
	}

	explicit operator bool() const final
	{
		return (bool)lockBuff;
	}

protected:
	IG::GlyphImage lockBuff{};
};

static int charIsDrawableAscii(int c)
{
	if(c >= firstDrawableAsciiChar && c <= lastDrawableAsciiChar)
		return 1;
	else return 0;
}

static int charIsDrawableUnicode(int c)
{
	return !(
			(c >= 0x0 && c < '!')
			|| (c > '~' && c < 0xA1)
			|| (c >= 0x2000 && c <= 0x200F)
			|| (c == 0x3000)
			);
}

bool GlyphTextureSet::initGlyphTable()
{
	logMsg("allocating glyph table, %d entries", glyphTableEntries);
	if(glyphTable)
		mem_free(glyphTable);
	glyphTable = (GlyphEntry*)mem_calloc(1, sizeof(GlyphEntry) * glyphTableEntries);
	if(!glyphTable)
	{
		logErr("out of memory");
		return false;
	}
	usedGlyphTableBits = 0;
	return true;
}

void GlyphTextureSet::freeCaches(uint32 purgeBits)
{
	auto tableBits = usedGlyphTableBits;
	iterateTimes(32, i)
	{
		if((tableBits & 1) && (purgeBits & 1))
		{
			logMsg("purging glyphs from table range %d/31", i);
			int firstChar = i << 11;
			iterateTimesFromStart(2048, firstChar, c)
			{
				uint tableIdx;
				if((bool)mapCharToTable(c, tableIdx))
				{
					//logMsg( "%c not a known drawable character, skipping", c);
					continue;
				}
				glyphTable[tableIdx].glyph.deinit();
			}
			usedGlyphTableBits = IG::clearBits(usedGlyphTableBits, IG::bit(i));
		}
		tableBits >>= 1;
		purgeBits >>= 1;
	}
}

GlyphTextureSet::GlyphTextureSet(Renderer &r, const char *path, IG::FontSettings set):
		GlyphTextureSet(r, std::make_unique<IG::Font>(path), set)
{}

GlyphTextureSet::GlyphTextureSet(Renderer &r, GenericIO io, IG::FontSettings set):
	GlyphTextureSet(r, std::make_unique<IG::Font>(std::move(io)), set)
{}

GlyphTextureSet::GlyphTextureSet(Renderer &r, std::unique_ptr<IG::Font> font, IG::FontSettings set):
	font{std::move(font)}
{
	if(set)
	{
		setFontSettings(r, set);
	}
	else
	{
		if(!initGlyphTable())
		{
			logErr("couldn't allocate glyph table");
		}
	}
}

GlyphTextureSet GlyphTextureSet::makeSystem(Renderer &r, IG::FontSettings set)
{
	return {r, std::make_unique<IG::Font>(IG::Font::makeSystem()), set};
}

GlyphTextureSet GlyphTextureSet::makeBoldSystem(Renderer &r, IG::FontSettings set)
{
	return {r, std::make_unique<IG::Font>(IG::Font::makeBoldSystem()), set};
}

GlyphTextureSet GlyphTextureSet::makeFromAsset(Renderer &r, const char *name, const char *appName, IG::FontSettings set)
{
	return {r, openAppAssetIO(name, IO::AccessHint::ALL, appName).makeGeneric(), set};
}

GlyphTextureSet::GlyphTextureSet(GlyphTextureSet &&o)
{
	swap(*this, o);
}

GlyphTextureSet &GlyphTextureSet::operator=(GlyphTextureSet o)
{
	swap(*this, o);
	return *this;
}

GlyphTextureSet::~GlyphTextureSet()
{
	if(glyphTable)
	{
		iterateTimes(glyphTableEntries, i)
		{
			glyphTable[i].glyph.deinit();
		}
		mem_free(glyphTable);
	}
}

GlyphTextureSet::operator bool() const
{
	return settings;
}

void GlyphTextureSet::swap(GlyphTextureSet &a, GlyphTextureSet &b)
{
	std::swap(a.settings, b.settings);
	std::swap(a.font, b.font);
	std::swap(a.glyphTable, b.glyphTable);
	std::swap(a.faceSize, b.faceSize);
	std::swap(a.nominalHeight_, b.nominalHeight_);
	std::swap(a.usedGlyphTableBits, b.usedGlyphTableBits);
}

uint GlyphTextureSet::nominalHeight() const
{
	return nominalHeight_;
}

void GlyphTextureSet::calcNominalHeight(Renderer &r)
{
	//logMsg("calcNominalHeight");
	GlyphEntry *mGly = glyphEntry(r, 'M');
	GlyphEntry *gGly = glyphEntry(r, 'g');

	assert(mGly && gGly);

	nominalHeight_ = mGly->metrics.ySize + (gGly->metrics.ySize/2);
}

bool GlyphTextureSet::setFontSettings(Renderer &r, IG::FontSettings set)
{
	if(set.pixelWidth() < font->minUsablePixels())
		set.setPixelWidth(font->minUsablePixels());
	if(set.pixelHeight() < font->minUsablePixels())
		set.setPixelHeight(font->minUsablePixels());
	if(set == settings)
		return false;
	if(settings && glyphTable)
	{
		logMsg("flushing glyph cache");
		iterateTimes(glyphTableEntries, i)
		{
			glyphTable[i].glyph.deinit();
		}
	}
	if(!initGlyphTable())
	{
		logErr("couldn't allocate glyph table");
	}
	settings = set;
	std::errc ec{};
	faceSize = font->makeSize(settings, ec);
	calcNominalHeight(r);
	return true;
}

std::errc GlyphTextureSet::cacheChar(Renderer &r, int c, int tableIdx)
{
	if(glyphTable[tableIdx].metrics.ySize == -1)
	{
		// failed to previously cache char
		return std::errc::invalid_argument;
	}
	// make sure applySize() has been called on the font object first
	std::errc ec{};
	auto res = font->glyph(c, faceSize, ec);
	if((bool)ec)
	{
		// mark failed attempt
		glyphTable[tableIdx].metrics.ySize = -1;
		return ec;
	}
	//logMsg("setting up table entry %d", tableIdx);
	glyphTable[tableIdx].metrics = res.metrics;
	auto img = GfxGlyphImage(std::move(res.image));
	glyphTable[tableIdx].glyph.init(r, img, false);
	usedGlyphTableBits |= IG::bit((c >> 11) & 0x1F); // use upper 5 BMP plane bits to map in range 0-31
	//logMsg("used table bits 0x%X", usedGlyphTableBits);
	return {};
}

static std::errc mapCharToTable(uint c, uint &tableIdx)
{
	if(GlyphTextureSet::supportsUnicode)
	{
		//logMsg("mapping char 0x%X", c);
		if(c < unicodeBmpChars && charIsDrawableUnicode(c))
		{
			if(c < unicodeBmpPrivateStart)
			{
				tableIdx = c;
				return {};
			}
			else if(c > unicodeBmpPrivateEnd)
			{
				tableIdx = c - unicodeBmpPrivateChars; // surrogate & private chars are a hole in the table
				return {};
			}
			else
			{
				return std::errc::invalid_argument;
			}
		}
		else
			return std::errc::invalid_argument;
	}
	else
	{
		if(charIsDrawableAscii(c))
		{
			tableIdx = c - firstDrawableAsciiChar;
			return {};
		}
		else
			return std::errc::invalid_argument;
	}
}

// TODO: update for unicode
std::errc GlyphTextureSet::precache(Renderer &r, const char *string)
{
	assert(settings);
	iterateTimes(strlen(string), i)
	{
		auto c = string[i];
		uint tableIdx;
		if((bool)mapCharToTable(c, tableIdx))
		{
			//logMsg( "%c not a known drawable character, skipping", c);
			continue;
		}
		if(glyphTable[tableIdx].glyph)
		{
			//logMsg( "%c already cached", c);
			continue;
		}
		logMsg("precaching char %c", c);
		cacheChar(r, c, tableIdx);
	}
	return {};
}

GlyphEntry *GlyphTextureSet::glyphEntry(Renderer &r, int c)
{
	assert(settings);
	uint tableIdx;
	if((bool)mapCharToTable(c, tableIdx))
		return nullptr;
	assert(tableIdx < glyphTableEntries);
	if(!glyphTable[tableIdx].glyph)
	{
		if((bool)cacheChar(r, c, tableIdx))
			return nullptr;
		logMsg("char 0x%X was not in table, cached", c);
	}
	return &glyphTable[tableIdx];
}

}
