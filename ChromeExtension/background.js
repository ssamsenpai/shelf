// One context menu entry on images, everywhere on the web.
// Chromium build: hands the image to the Shelf app through the shelf:// scheme,
// no native messaging host needed.

chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
        id: "add-to-shelf",
        title: "Add to My Shelf",
        contexts: ["image"]
    });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId !== "add-to-shelf" || !info.srcUrl) { return; }

    const params = new URLSearchParams({
        url: info.srcUrl,
        page: info.pageUrl || (tab && tab.url) || "",
        title: (tab && tab.title) || ""
    });

    // Navigating the current tab to the custom scheme launches Shelf. The page
    // itself stays put, the navigation is consumed by the protocol handler.
    if (tab && tab.id) {
        chrome.tabs.update(tab.id, { url: "shelf://add?" + params.toString() });
    }
});
