*** Settings ***
Documentation     Robot Framework script to scrape news from Al Jazeera website
Library           RPA.Browser.Selenium
Library           RPA.Excel.Files
Library           RPA.HTTP
Library           RPA.Robocorp.WorkItems
Library           RPA.FileSystem
Library           Collections
Library           yaml
Library    OperatingSystem
Library    DateTime
Library    String
Suite Setup       Setup
# Suite Teardown    Teardown

*** Variables ***
${CONFIG_FILE}    config.yaml
${BASE_URL}       https://apnews.com/
${EXCEL_FILE}     output/news_data.xlsx

*** Tasks ***
Scrape Al Jazeera News
    Open the Al Jazeera website
    Search for the news    ${SEARCH_PHRASE}
    Filter news by category    ${NEWS_CATEGORY}
    ${news_data}=    Get news data and save to Excel    ${MONTHS}    ${SEARCH_PHRASE}
    Download pictures and update Excel    ${news_data}

*** Keywords ***
Setup
    Load Configuration

# Teardown
#     Close All Browsers

Load Configuration
    ${config}=    Get File    ${CONFIG_FILE}
    Set Suite Variable    ${SEARCH_PHRASE}    newest    #${config['search_phrase']}
    Set Suite Variable    ${NEWS_CATEGORY}    newest    #${config['news_category']}
    Set Suite Variable    ${MONTHS}    3    #${config['months']}

Open the Al Jazeera website
    Open Available Browser    ${BASE_URL}

Search for the news
    [Arguments]    ${search_phrase}
    Click Button When Visible    css.SearchOverlay-search-button
    Input Text     input[type="search"]    ${search_phrase}
    Press Keys     input[type="search"]    ENTER
    Wait Until Page Contains Element    css:.search-result-article

Filter news by category
    [Arguments]    ${news_category}
    Run Keyword Unless    '${news_category}' == ''    Click Link    ${news_category}

Get news data and save to Excel
    [Arguments]    ${months}    ${search_phrase}
    ${end_date}=    Get Current Date
    ${start_date}=    Subtract Time From Date    ${end_date}    months=${months}
    ${articles}=    Get WebElements    css:.search-result-article
    Create Workbook    ${EXCEL_FILE}
    Create Worksheet    Sheet1
    FOR    ${article}    IN    @{articles}
        ${title}=    Get Element Attribute    css:h3 a    ${article}
        ${date_str}=    Get Element Attribute    css:time    ${article}
        ${description}=    Get Element Attribute    css:p    ${article}
        ${date}=    Convert Date    ${date_str}
        Run Keyword If    '${start_date}' <= '${date}' <= '${end_date}'    Append To Excel    ${title}    ${date}    ${description}    ${search_phrase}
    END
    Save Workbook    ${EXCEL_FILE}
    ${news_data}=    Read Worksheet As Table    ${EXCEL_FILE}    Sheet1
    [Return]    ${news_data}

Append To Excel
    [Arguments]    ${title}    ${date}    ${description}    ${search_phrase}
    ${search_count}=    Get Search Phrase Count    ${title}    ${description}    ${search_phrase}
    ${money_present}=    Check For Money    ${title}    ${description}
    Append Rows To Worksheet    ${EXCEL_FILE}    Sheet1    ${title}    ${date}    ${description}    ${search_count}    ${money_present}

Download pictures and update Excel
    [Arguments]    ${news_data}
    FOR    ${row}    IN    @{news_data}
        ${picture_url}=    Get Element Attribute    css:img    ${row.title}
        ${picture_filename}=    Save Picture    ${picture_url}    ${row.title}
        Set Worksheet Value    ${EXCEL_FILE}    Sheet1    F${row.index+1}    ${picture_filename}
    END
    Save Workbook    ${EXCEL_FILE}

Get Search Phrase Count
    [Arguments]    ${title}    ${description}    ${search_phrase}
    ${search_count_title}=    Get Count Of Phrase    ${title}    ${search_phrase}
    ${search_count_description}=    Get Count Of Phrase    ${description}    ${search_phrase}
    ${total_search_count}=    Evaluate    ${search_count_title} + ${search_count_description}
    [Return]    ${total_search_count}

Check For Money
    [Arguments]    ${text1}    ${text2}
    ${pattern}=    Set Variable    \${d+(\.\d+)?|\d+ dollars|\d+ USD}
    ${match1}=    Run Keyword And Return Status    Should Match Regexp    ${text1}    ${pattern}
    ${match2}=    Run Keyword And Return Status    Should Match Regexp    ${text2}    ${pattern}
    ${money_present}=    Evaluate    ${match1} or ${match2}
    [Return]    ${money_present}

Get Count Of Phrase
    [Arguments]    ${text}    ${phrase}
    ${count}=    Get Matches    ${text}    (?i)${phrase}
    ${count}=    Get Length    ${count}
    [Return]    ${count}

Save Picture
    [Arguments]    ${url}    ${title}
    ${filename}=    Replace String    ${title}    [^a-zA-Z0-9]    _
    ${filepath}=    Set Variable    images/${filename}.jpg
    Download    ${url}    ${filepath}
    [Return]    ${filepath}