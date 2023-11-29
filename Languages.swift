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

let languageFlagEmojiDict: [String: String] = [
    "Afrikaans": "🇿🇦",
    "Arabic": "🇸🇦", // Saudi Arabia, could also be any Arabic-speaking country
    "Armenian": "🇦🇲",
    "Azerbaijani": "🇦🇿",
    "Belarusian": "🇧🇾",
    "Bosnian": "🇧🇦",
    "Bulgarian": "🇧🇬",
    "Catalan": "🏳", // Catalonia does not have an official country flag emoji
    "Chinese": "🇨🇳",
    "Croatian": "🇭🇷",
    "Czech": "🇨🇿",
    "Danish": "🇩🇰",
    "Dutch": "🇳🇱",
    "English": "🇬🇧", // United Kingdom
    "Estonian": "🇪🇪",
    "Finnish": "🇫🇮",
    "French": "🇫🇷",
    "Galician": "🏳", // Galicia does not have an official country flag emoji
    "German": "🇩🇪",
    "Greek": "🇬🇷",
    "Hebrew": "🇮🇱", // Israel, as Hebrew is predominantly spoken there
    "Hindi": "🇮🇳",
    "Hungarian": "🇭🇺",
    "Icelandic": "🇮🇸",
    "Indonesian": "🇮🇩",
    "Italian": "🇮🇹",
    "Japanese": "🇯🇵",
    "Kannada": "🇮🇳", // India, as Kannada is a regional language there
    "Kazakh": "🇰🇿",
    "Korean": "🇰🇷",
    "Latvian": "🇱🇻",
    "Lithuanian": "🇱🇹",
    "Macedonian": "🇲🇰",
    "Malay": "🇲🇾", // Malaysia
    "Marathi": "🇮🇳", // India, as Marathi is a regional language there
    "Maori": "🇳🇿", // New Zealand
    "Nepali": "🇳🇵",
    "Norwegian": "🇳🇴",
    "Persian": "🇮🇷", // Iran, as Persian is predominantly spoken there
    "Polish": "🇵🇱",
    "Portuguese": "🇵🇹", // Portugal, but could also be Brazil
    "Romanian": "🇷🇴",
    "Russian": "🇷🇺",
    "Serbian": "🇷🇸",
    "Slovak": "🇸🇰",
    "Slovenian": "🇸🇮",
    "Spanish": "🇪🇸",
    "Swahili": "🇰🇪", // Kenya, but Swahili is also spoken in other East African countries
    "Swedish": "🇸🇪",
    "Tagalog": "🇵🇭", // Philippines
    "Tamil": "🇮🇳", // India, as Tamil is a regional language there, but could also be Sri Lanka
    "Thai": "🇹🇭",
    "Turkish": "🇹🇷",
    "Ukrainian": "🇺🇦",
    "Urdu": "🇵🇰", // Pakistan, though Urdu is also spoken in India
    "Vietnamese": "🇻🇳",
    "Welsh": "🏴󠁧󠁢󠁷󠁬󠁳󠁿"
]

let languageOptions: [String] = Array(languageWritingSystems.keys)

let languageSpecificRulesDict: [String: String] = [
    "Korean": """
* Use only the 요, not the formal 니다 form, unless the user themselves included a formal 니다 form in their transcription.
* Not using the polite form, with 요 in the right places, counts as a mistake you should correct.
"""
]

enum LanguageError: Error {
    case unsupportedLanguage
}
