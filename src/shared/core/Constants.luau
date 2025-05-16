local Constants = {}

-- Admin Configuration
Constants.ADMIN_IDS = {
    7768610061 -- Main admin ID
}

-- Item Categories
Constants.ITEM_CATEGORIES = {
    FREEBIES = "Freebies",
    PAID = "Paid",
    ADMIN = "Admin"
}

-- Item Actions
Constants.ITEM_ACTIONS = {
    clone = { cost = 100 },
    move = { cost = 10 },
    rotate = { cost = 5 },
    destroy = { cost = 20 }
}

-- Currency Configuration
Constants.CURRENCY = {
    INGAME = "Coins",
    ROBUX = "Robux",
    REWARD_RATE = 1.67, -- Coins per real minute
    REWARD_INTERVAL = 60, -- Reward interval in seconds
    MIN_REWARD_AMOUNT = 1, -- Minimum reward amount
    MAX_REWARD_AMOUNT = 100, -- Maximum reward amount
    DAILY_BONUS = 100, -- Daily login bonus
    WEEKLY_BONUS = 500, -- Weekly login bonus
    MONTHLY_BONUS = 2000, -- Monthly login bonus
    STARTING_COINS = 100, -- Added for client and most scripts
    STARTING_CURRENCY = 100, -- Added for server/GameManager

    PRODUCTS = {
        {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 3285357280, description = "Get started with a handy pack of 1,000 coins!"},
        {id = "coins_5000", name = "5,500 Coins", coins = 5000, robux = 350, bonusCoins = 500, assetId = 3285387112, description = "Great value! Grab 5,000 coins and get an extra 500 on us!"},
        {id = "coins_10000", name = "11,500 Coins", coins = 10000, robux = 650, bonusCoins = 1500, assetId = 3285387112, description = "Supercharge your game with 10,000 coins, plus a 1,500 coin bonus!"},
        {id = "coins_20000", name = "24,000 Coins", coins = 20000, robux = 1200, bonusCoins = 4000, assetId = 3285387781, description = "The ultimate deal! Get 20,000 coins and a massive 4,000 coin bonus!"}
    }
}

-- Item Pricing Configuration
Constants.ITEM_PRICES = {
    BASIC = {
        INGAME = 5, -- 5 coins
        ROBUX = 5 -- 5 Robux
    },
    LEVEL_1 = {
        INGAME = 10, -- 10 coins
        ROBUX = 10 -- 10 Robux
    },
    LEVEL_2 = {
        INGAME = 25, -- 25 coins
        ROBUX = 25 -- 25 Robux
    },
    RARE = {
        INGAME = 100, -- 100 coins
        ROBUX = 100 -- 100 Robux
    },
    EXCLUSIVE = {
        INGAME = 1000, -- 1000 coins
        ROBUX = 1000 -- 1000 Robux
    },
    WEAPONS = {
        INGAME = 500, -- 500 coins
        ROBUX = 500 -- 500 Robux
    },
    RARE_DROP = {
        INGAME = 800, -- 800 coins
        ROBUX = 800 -- 800 Robux
    },
    FREE_ITEMS = {
        INGAME = 0, -- 0 coins
        ROBUX = 0 -- 0 Robux
    }
}

-- Pricing Configuration
Constants.BASE_PRICES = {
    BUY = 10, -- Base price for buying items
    MOVE = 5, -- Base price for moving items
    DESTROY = 3, -- Base price for destroying items
    ROTATE = 2, -- Base price for rotating items
    COLOR = 2 -- Base price for changing color
}

-- Homebase Configuration
Constants.HOMEBASE = {
    RADIUS = 50, -- Radius of homebase area
    CENTER = Vector3.new(0, 0, 0) -- Center point of homebase
}

-- Inventory Configuration
Constants.INVENTORY = {
    MAX_SLOTS = 50,
    MAX_STACK_SIZE = 99
}

-- Item Properties
Constants.ITEM_PROPERTIES = {
    MAX_ROTATION = 360, -- Maximum rotation in degrees
    MIN_ROTATION = 0,
    ROTATION_STEP = 45, -- Rotation step in degrees
    MAX_COLOR_CHANGES = 5 -- Maximum number of color changes allowed
}

Constants.UI_COLORS = {
    PRIMARY = Color3.fromRGB(0, 170, 255),
    SECONDARY = Color3.fromRGB(40, 40, 40),
    TEXT = Color3.fromRGB(255, 255, 255)
}

Constants.ITEMS = {
    ["Basic"] = {
        icon = "rbxassetid://3284930147",
        description = "A red cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5}
    },
    ["Level_1"] = {
        icon = "rbxassetid://3284930700",
        description = "A Level 1 item.",
        tier = "LEVEL_1",
        price = {INGAME = 10, ROBUX = 10}
    },
    ["Level_2"] = {
        icon = "rbxassetid://3284930700",
        description = "A Level 2 item.",
        tier = "LEVEL_2",
        price = {INGAME = 25, ROBUX = 25}
    },
    ["Secondary"] = {
        icon = "rbxassetid://3284930700",
        description = "A Secondary Item.",
        tier = "SECONDARY",
        price = {INGAME = 15, ROBUX = 15}
    },
    ["Rare"] = {
        icon = "rbxassetid://3284930992",
        description = "A rare Item.",
        tier = "RARE",
        price = {INGAME = 100, ROBUX = 100}
    },
    ["Exclusive"] = {
        icon = "rbxassetid://3284931476",
        description = "An exclusive Item.",
        tier = "EXCLUSIVE",
        price = {INGAME = 1000, ROBUX = 1000}
    },
    ["Weapons"] = {
        icon = "rbxassetid://3284931476",
        description = "A weapon item.",
        tier = "WEAPONS",
        price = {INGAME = 500, ROBUX = 500}
    },
    ["Rare_Drop"] = {
        icon = "rbxassetid://3284931476",
        description = "A rare drop item.",
        tier = "RARE_DROP",
        price = {INGAME = 800, ROBUX = 800}
    },
    ["Free_Items"] = {
        icon = "rbxassetid://3284931476",
        description = "A free item.",
        tier = "FREE_ITEMS",
        price = {INGAME = 0, ROBUX = 0}
    }
    -- Add more items as needed
}

-- Developer Products for Item Tiers
Constants.TIER_PRODUCTS = {
    BASIC = {id = "tier_basic", assetId = 3285357280, robux = 5},
    LEVEL_1 = {id = "tier_level1", assetId = 3285357280, robux = 10},
    LEVEL_2 = {id = "tier_level2", assetId = 3285357280, robux = 25},
    SECONDARY = {id = "tier_secondary", assetId = 3285387112, robux = 15},
    RARE = {id = "tier_rare", assetId = 3285387112, robux = 100},
    EXCLUSIVE = {id = "tier_exclusive", assetId = 3285387781, robux = 1000},
    WEAPONS = {id = "tier_weapons", assetId = 3285387781, robux = 500},
    RARE_DROP = {id = "tier_rare_drop", assetId = 3285387781, robux = 800}
}

return Constants