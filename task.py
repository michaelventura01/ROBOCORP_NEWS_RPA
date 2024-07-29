from RPA.Browser.Selenium import Selenium
from RPA.Excel.Files import Files
from RPA.HTTP import HTTP
from RPA.Robocorp.WorkItems import WorkItems
import re
from datetime import datetime, timedelta

# Initialize libraries
browser = Selenium()
excel = Files()
http = HTTP()
workitems = WorkItems()

# Open the work item
workitems.get_input_work_item()

# Get parameters from the work item
search_phrase = workitems.get_work_item_variable("search_phrase")
news_category = workitems.get_work_item_variable("news_category")
months = int(workitems.get_work_item_variable("months"))

# Calculate the date range based on the number of months
end_date = datetime.now()
start_date = end_date - timedelta(days=months * 30)

# Define the Al Jazeera URL
base_url = "https://www.aljazeera.com/"

def open_website():
    browser.open_available_browser(base_url)

def search_news():
    browser.input_text('input[type="search"]', search_phrase)
    browser.press_keys('input[type="search"]', "ENTER")
    browser.wait_until_page_contains_element("css:.search-result-article", timeout=10)

def filter_news():
    if news_category:
        browser.click_link(news_category)

def get_news_data():
    articles = browser.find_elements("css:.search-result-article")
    news_data = []
    for article in articles:
        title = browser.find_element("css:h3 a", parent=article).text
        date_str = browser.find_element("css:time", parent=article).get_attribute("datetime")
        description = browser.find_element("css:p", parent=article).text
        date = datetime.fromisoformat(date_str.replace("Z", "+00:00"))

        if start_date <= date <= end_date:
            news_data.append({
                "title": title,
                "date": date.strftime("%Y-%m-%d"),
                "description": description,
                "picture_url": browser.find_element("css:img", parent=article).get_attribute("src")
            })

    return news_data

def save_to_excel(news_data):
    excel.create_workbook("news_data.xlsx")
    for news in news_data:
        title = news["title"]
        description = news["description"]
        picture_url = news["picture_url"]

        # Count search phrases
        search_count = title.lower().count(search_phrase.lower()) + description.lower().count(search_phrase.lower())

        # Check for monetary amounts
        money_present = bool(re.search(r'\$\d+(\.\d+)?|\d+ dollars|\d+ USD', title + description))

        # Download the picture
        picture_filename = f"images/{title[:30]}.jpg"
        http.download(picture_url, picture_filename)

        # Save to Excel
        excel.append_worksheet({
            "Title": title,
            "Date": news["date"],
            "Description": description,
            "Picture Filename": picture_filename,
            "Search Phrase Count": search_count,
            "Contains Money": money_present
        })

    excel.save_workbook()

def main():
    open_website()
    search_news()
    filter_news()
    news_data = get_news_data()
    save_to_excel(news_data)
    browser.close_all_browsers()

if __name__ == "__main__":
    main()