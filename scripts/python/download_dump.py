import requests
from datetime import datetime
from datetime import timedelta
from string import Template
from tqdm import tqdm
from typing import Union


def download_latest_dump(lang_code: str, download_file: str, from_date: Union[datetime, str] = datetime.now(), chunksize: int = 8192) -> None:
    download_link_template = Template("https://dumps.wikimedia.org/${lang_code}wiki/$date/${lang_code}wiki-$date-pages-articles-multistream.xml.bz2")

    if isinstance(from_date, str):
        from_date = datetime.strptime(from_date, "%Y%m%d")
    
    def get_last_dump_date(date: datetime = from_date) -> datetime:
        is_valid_page = False
        wiki_link_template = Template("https://dumps.wikimedia.org/${lang_code}wiki/$date/")
        link = wiki_link_template.substitute(lang_code=lang_code, date=date.strftime("%Y%m%d"))

        while not is_valid_page:
            response = requests.get(link)
            if response.status_code == 404:
                date -= timedelta(days=1)
                link = wiki_link_template.substitute(lang_code=lang_code, date=date.strftime("%Y%m%d"))
            else:
                is_valid_page = True
                return date.strftime("%Y%m%d")

    last_dump_date = get_last_dump_date(from_date)
    download_link = download_link_template.substitute(lang_code=lang_code, date=last_dump_date)

    with requests.get(download_link, stream=True) as l:
        l.raise_for_status()

        with open(download_file, "wb") as f:
            for chunk in tqdm(l.iter_content(chunk_size=chunksize)):
                f.write(chunk)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser("Download Wikipedia Dump")
    parser.add_argument("--language", type=str)
    parser.add_argument("--download_file",  type=str)
    # parser.add_argument("--from_date", type=str, default=datetime.now())
    parser.add_argument("--chunksize", type=int, default=8192)
    args = parser.parse_args()

    download_latest_dump(
        lang_code=args.language,
        download_file=args.download_file,
        chunksize=args.chunksize
    )
