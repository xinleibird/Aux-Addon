module 'aux.tabs.bids'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab '竞拍'

auction_records = {}

function tab.OPEN()
    frame:Show()
    scan_bids()
end

function tab.CLOSE()
    frame:Hide()
end

function update_listing()
    listing:SetDatabase(auction_records)
end

function M.scan_bids()

    status_bar:update_status(0, 0)
    status_bar:set_text('|cff3399ff扫描拍卖...|r')

    T.wipe(auction_records)
    update_listing()
    scan.start{
        type = 'bidder',
        queries = T.list(T.map('blizzard_query', T.acquire())),
        on_page_loaded = function(page, total_pages)
            status_bar:update_status(page / total_pages, 0)
            status_bar:set_text(format('|cff3399ff扫描中|r (第 |cffff8000%d|r / |cff00ff00%d|r 页)', page, total_pages))
        end,
        on_auction = function(auction_record)
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            status_bar:update_status(1, 1)
            status_bar:set_text('|cff00ff00扫描完成|r')
            update_listing()
        end,
        on_abort = function()
            status_bar:update_status(1, 1)
            status_bar:set_text('|cffff0000扫描终止|r')
        end,
    }
end

do
    local current_record

    function purchase_verify(record, kind)
        local scan_id = scan_util.find(
            record,
            status_bar,
            function() end,
            function()
                aux.print('该拍卖已失效')
                listing:RemoveAuctionRecord(record)
            end,
            function(index)
                if not listing:ContainsRecord(record) then return end
                if kind == 'bid' then
                    aux.place_bid('bidder', index, record.bid_price, record.bid_price < record.buyout_price and function()
                        info.bid_update(record)
                        listing:SetDatabase()
                    end or function() listing:RemoveAuctionRecord(record) end)
                else
                    aux.place_bid('bidder', index, record.buyout_price, function() listing:RemoveAuctionRecord(record) end)
                end
            end
        )
    end

    function update_buttons(record)
        if not record then
            bid_button:Disable()
            buyout_button:Disable()
            return
        end

        if not record.high_bidder then
            bid_button:SetScript('OnClick', function()
                purchase_verify(record, 'bid')
            end)
            bid_button:Enable()
        else
            bid_button:Disable()
        end

        if record.buyout_price > 0 then
            buyout_button:SetScript('OnClick', function()
                purchase_verify(record, 'buyout')
            end)
            buyout_button:Enable()
        else
            buyout_button:Disable()
        end
    end

    function on_update()
        local selection = listing:GetSelection()
        local record = selection and selection.record
        if record == current_record then return end
        current_record = record
        update_buttons(record)
    end
end