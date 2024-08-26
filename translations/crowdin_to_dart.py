import collections
import re
import zipfile
import json

lang_crowdin = {
    "ar": "ar_ar",
    "ast": "ast_es",
    "bg": "bul_bg",
    "cs": "cs_cz",
    "de": "de_de",
    "el": "el_gr",
    "es-ES": "es_es",
    "fa": "fa_ir",
    "fil": "fil_ph",
    "fr": "fr_fr",
    "he": "he_il",
    "hi": "hi_in",
    "hr": "hr_hr",
    "hu": "hu_hu",
    "id": "id_id",
    "it": "it_it",
    "ko": "ko_ko",
    "nl": "nl_nl",
    "pl": "pl_pl",
    "pt-BR": "pt_br",
    "ro": "ro_ro",
    "ru": "ru_ru",
    "sk": "sk_sk",
    "sl": "sl_sl",
    "tr": "tr_tr",
    "uk": "uk_ua",
    "ur-PK": "ur_pk",
    "uwu": "uwu_uwu",
    "vi": "vi_vi",
    "zh-CN": "zh_cn",
}


def convert_to_single_quotes(json_str):
    def replace_quotes(match):
        key, value = match.groups()
        if "'" in key:
            key = f'"{key}"'
        else:
            key = f"'{key}'"
        if "'" in value:
            value = f'"{value}"'
        else:
            value = f"'{value}'"
        return f"{key}: {value}"

    def replace_locale_quotes(match):
        locale = match.group(1)
        return f"'{locale}': {{"

    pattern = r'"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)"'
    single_quote_json = re.sub(pattern, replace_quotes, json_str)

    locale_pattern = r'"(\w+_\w+)":\s*{'
    single_quote_json = re.sub(locale_pattern, replace_locale_quotes, single_quote_json)

    return single_quote_json


# Run `dart fix --apply --code=prefer_single_quotes` in `refreezer\lib\languages\` afterwards
def generate_dart():
    out = {}
    with zipfile.ZipFile("ReFreezer (translations).zip") as zip:
        files = sorted(zip.namelist())
        for file in files:
            if "refreezer.json" in file:
                data = zip.open(file).read().decode("utf-8")
                lang = file.split("/")[0]
                if lang in lang_crowdin:
                    out[lang_crowdin[lang]] = json.loads(
                        data, object_pairs_hook=collections.OrderedDict
                    )

    with open("../lib/languages/crowdin_new.dart", "w", encoding="utf-8") as f:
        data = json.dumps(out, ensure_ascii=False, indent=2).replace("$", r"\$")
        single_quote_data = convert_to_single_quotes(data)
        out = f"const crowdin = {single_quote_data};"
        f.write(out)


if __name__ == "__main__":
    generate_dart()
