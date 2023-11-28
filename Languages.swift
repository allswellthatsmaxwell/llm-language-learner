//
//  Languages.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/27/23.
//

import Foundation

let languageWritingSystems: [String: String] = [
    "Afrikaans": "Afrikaans alphabet",
    "Arabic": "Arabic script",
    "Armenian": "Armenian script",
    "Azerbaijani": "Azerbaijani alphabet", // Also uses Cyrillic and Arabic in some regions.
    "Belarusian": "Belarusian Cyrillic script",
    "Bosnian": "Bosnian alphabet",
    "Bulgarian": "Bulgarian Cyrillic script",
    "Catalan": "Catalan alphabet",
    "Chinese": "Chinese characters",
    "Croatian": "Croatian alphabet",
    "Czech": "Czech alphabet",
    "Danish": "Danish alphabet",
    "Dutch": "Dutch alphabet",
    "English": "English alphabet",
    "Estonian": "Estonian alphabet",
    "Finnish": "Finnish alphabet",
    "French": "French alphabet",
    "Galician": "Galician alphabet",
    "German": "German alphabet",
    "Greek": "Greek script",
    "Hebrew": "Hebrew script",
    "Hindi": "Devanagari script",
    "Hungarian": "Hungarian alphabet",
    "Icelandic": "Icelandic alphabet",
    "Indonesian": "Indonesian alphabet",
    "Italian": "Italian alphabet",
    "Japanese": "Japanese characters", // Includes Kanji, Hiragana, and Katakana.
    "Kannada": "Kannada script",
    "Kazakh": "Kazakh alphabet", // Also uses Cyrillic and Arabic scripts.
    "Korean": "Hangul",
    "Latvian": "Latvian alphabet",
    "Lithuanian": "Lithuanian alphabet",
    "Macedonian": "Macedonian Cyrillic script",
    "Malay": "Malay alphabet",
    "Marathi": "Devanagari script",
    "Maori": "Maori alphabet",
    "Nepali": "Devanagari script",
    "Norwegian": "Norwegian alphabet",
    "Persian": "Persian script",
    "Polish": "Polish alphabet",
    "Portuguese": "Portuguese alphabet",
    "Romanian": "Romanian alphabet",
    "Russian": "Russian Cyrillic script",
    "Serbian": "Serbian scripts", // Uses both Cyrillic and Latin scripts.
    "Slovak": "Slovak alphabet",
    "Slovenian": "Slovenian alphabet",
    "Spanish": "Spanish alphabet",
    "Swahili": "Swahili alphabet",
    "Swedish": "Swedish alphabet",
    "Tagalog": "Tagalog alphabet",
    "Tamil": "Tamil script",
    "Thai": "Thai script",
    "Turkish": "Turkish alphabet",
    "Ukrainian": "Ukrainian Cyrillic script",
    "Urdu": "Urdu script",
    "Vietnamese": "Vietnamese alphabet",
    "Welsh": "Welsh alphabet"
]

let languageSpecificRulesDict: [String: String] = [
    "Korean": """
* Use only the 요, not the formal 니다 form, unless the user themselves included a formal 니다 form in their transcription.
* Not using the polite form, with 요 in the right places, counts as a mistake you should correct.
"""
]
