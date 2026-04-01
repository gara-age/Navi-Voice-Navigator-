NAVER_MAP_LOCATORS = {
    "route_tab": [
        "a[role='button']",
        "button[aria-label*='route']",
        "button[aria-label*='\uAE38\uCC3E\uAE30']",
    ],
    "origin_input": [
        "input[placeholder*='\uCD9C\uBC1C']",
        "input[aria-label*='\uCD9C\uBC1C']",
        "input.input_search",
    ],
    "destination_input": [
        "input[placeholder*='\uB3C4\uCC29']",
        "input[aria-label*='\uB3C4\uCC29']",
        "input.input_search",
    ],
    "route_items": [
        ".route_result_item",
        ".section_direction .item",
        "[role='listitem']",
    ],
}
