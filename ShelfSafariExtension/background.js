// One context menu entry on images, everywhere on the web.
browser.contextMenus.create({
    id: "add-to-shelf",
    title: "Add to My Shelf",
    contexts: ["image"]
});

browser.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId !== "add-to-shelf" || !info.srcUrl) { return; }

    browser.runtime.sendNativeMessage("application.id", {
        url: info.srcUrl,
        page: info.pageUrl || (tab && tab.url) || "",
        title: (tab && tab.title) || ""
    });
});
