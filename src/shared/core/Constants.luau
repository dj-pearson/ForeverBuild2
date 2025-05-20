local Constants = {}

-- Admin Configuration
Constants.ADMIN_IDS = {
    7768610061 -- Main admin ID
}
Constants.ADMIN_NAMES = {
    "Xdjpearsonx"
}

function Constants.isAdminPlayerName(name)
    for _, adminName in ipairs(Constants.ADMIN_NAMES) do
        if string.lower(name) == string.lower(adminName) then
            return true
        end
    end
    return false
end

-- Item Categories
Constants.ITEM_CATEGORIES = {
    FREEBIES = "Freebies",
    PAID = "Paid",
    ADMIN = "Admin"
}

-- Item Actions - Costs are multipliers of the item's original priceIngame
Constants.ITEM_ACTIONS = {
    clone = { name = "Clone", costMultiplier = 1.0, icon = "rbxassetid://placeholder_clone_icon" },     -- 100% of item price
    move = { name = "Move", costMultiplier = 0.6, icon = "rbxassetid://placeholder_move_icon" },       -- 60% of item price
    recall = { name = "Recall", costMultiplier = 0.2, icon = "rbxassetid://placeholder_recall_icon" },   -- 20% of item price
    destroy = { name = "Destroy", costMultiplier = 0.8, icon = "rbxassetid://placeholder_destroy_icon" }, -- 80% of item price (player pays to destroy)
    rotate = { name = "Rotate", costMultiplier = 0.05, icon = "rbxassetid://placeholder_rotate_icon" }   -- 5% of item price (can be 0 for free rotation)
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
    STARTING_COINS = 200, -- Starting coins for client
    STARTING_CURRENCY = 200, -- Starting currency for server/GameManager

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

Constants.ITEMS = {
    ["Weapons"] = {
        name = "Weapons",
        icon = "rbxassetid://3284931476",
        description = "A weapon item.",
        tier = "WEAPONS",
        price = {INGAME = 500, ROBUX = 500},
        priceIngame = 500
    },
    ["Rare_Drop"] = {
        name = "Rare Drop",
        icon = "rbxassetid://3284931476",
        description = "A rare drop item.",
        tier = "RARE_DROP",
        price = {INGAME = 800, ROBUX = 800},
        priceIngame = 800
    },
    ["Free_Items"] = {
        name = "Free Items",
        icon = "rbxassetid://3284931476",
        description = "A free item.",
        tier = "FREE_ITEMS",
        price = {INGAME = 0, ROBUX = 0},
        priceIngame = 0
    },
    ["Glow_Yellow_Cube"] = {
        name = "Glow Yellow Cube",
        icon = "rbxassetid://128806170181723",
        description = "A neon yellow glowing cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Glow_Blue_Cube"] = {
        name = "Glow Blue Cube",
        icon = "rbxassetid://84435381312905",
        description = "A neon blue glowing cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Glow_Green_Cube"] = {
        name = "Glow Green Cube",
        icon = "rbxassetid://77860477722817",
        description = "A neon green glowing cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Glow_Purple_Cube"] = {
        name = "Glow Purple Cube",
        icon = "rbxassetid://115648931142692",
        description = "A neon purple glowing cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Glow_Red_Cube"] = {
        name = "Glow Red Cube",
        icon = "rbxassetid://116289336251008",
        description = "A neon red glowing cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Glow_White_Cube"] = {
        name = "Glow White Cube",
        icon = "rbxassetid://95637772062921",
        description = "A neon white glowing cube.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Brick_Cube"] = {
        name = "Brick Cube",
        icon = "rbxassetid://120615102380248",
        description = "A basic brick cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Corner_Wedge"] = {
        name = "Corner Wedge",
        description = "A corner wedge block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Fabric_Cube"] = {
        name = "Fabric Cube",
        icon = "rbxassetid://117472884483839",
        description = "A basic fabric cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Fire_Cube"] = {
        name = "Fire Cube",
        icon = "rbxassetid://71681608603027",
        description = "A basic fire cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Glass_Cube"] = {
        name = "Glass Cube",
        icon = "rbxassetid://83368835795295",
        description = "A basic glass cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Grass_Cube"] = {
        name = "Grass Cube",
        icon = "rbxassetid://110439433453247",
        description = "A basic grass cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Stone_Cube"] = {
        name = "Stone Cube",
        icon = "rbxassetid://138758138144155",
        description = "A basic stone cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Triangle_Wedge"] = {
        name = "Triangle Wedge",
        description = "A triangle wedge block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Water_Cube"] = {
        name = "Water Cube",
        icon = "rbxassetid://106216379689688",
        description = "A basic water cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Wood_Cube"] = {
        name = "Wood Cube",
        icon = "rbxassetid://132345081847393",
        description = "A basic wood cube building block.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Torch"] = {
        name = "Torch",
        icon = "rbxassetid://83703249522854",
        description = "A torch.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Unknown_Item"] = {
        name = "Unknown Item",
        icon = "rbxassetid://3284930147",
        description = "An unknown item.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Wood_Plank"] = {
        name = "Wood Plank",
        icon = "rbxassetid://your_wood_plank_icon_id",
        description = "A sturdy wood plank.",
        tier = "BASIC",
        price = {INGAME = 5, ROBUX = 5},
        priceIngame = 5
    },
    ["Rare_Outside_Hedge"] = {
        name = "Rare Outside Hedge",
        icon = "rbxassetid://3284930147",
        description = "A rare decorative hedge.",
        tier = "RARE",
        price = {INGAME = 100, ROBUX = 100},
        priceIngame = 100
    }
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

-- UI Configuration
Constants.UI = {
    Colors = {
        -- Theme Colors
        ThemePrimary = Color3.fromRGB(25, 118, 210),    -- A modern, slightly desaturated blue
        ThemeSecondary = Color3.fromRGB(100, 181, 246),  -- A lighter, complementary blue
        ThemeAccent = Color3.fromRGB(255, 193, 7),       -- A warm, inviting yellow/gold accent

        -- Neutral Grays
        BackgroundPrimary = Color3.fromRGB(28, 28, 30),    -- Very dark gray, almost black (main background)
        BackgroundSecondary = Color3.fromRGB(44, 44, 46),  -- Slightly lighter gray (panel/card backgrounds)
        BackgroundTertiary = Color3.fromRGB(60, 60, 62),   -- Even lighter gray (dividers, subtle elements)

        Border = Color3.fromRGB(70, 70, 72),             -- Subtle border color

        -- Text Colors
        TextPrimary = Color3.fromRGB(245, 245, 245),     -- Off-white for primary text
        TextSecondary = Color3.fromRGB(180, 180, 180),   -- Lighter gray for secondary/less important text
        TextDisabled = Color3.fromRGB(120, 120, 120),    -- Gray for disabled text/elements
        TextOnPrimary = Color3.fromRGB(255, 255, 255),   -- White text for on ThemePrimary backgrounds
        TextOnAccent = Color3.fromRGB(28, 28, 30),       -- Dark text for on ThemeAccent backgrounds

        -- State Colors
        Error = Color3.fromRGB(229, 57, 53),          -- Material Design Red
        Success = Color3.fromRGB(67, 160, 71),        -- Material Design Green
        Warning = Color3.fromRGB(251, 192, 45),       -- Material Design Amber
        Info = Color3.fromRGB(3, 169, 244),           -- Material Design Light Blue

        -- Legacy (can be phased out or mapped)
        -- Background = Color3.fromRGB(30, 30, 30), -- Kept for now, maps to BackgroundSecondary or Primary
        -- Text = Color3.fromRGB(240, 240, 240),   -- Kept for now, maps to TextPrimary
        -- Primary = Color3.fromRGB(0, 122, 204),  -- Kept for now, maps to ThemePrimary
        -- Secondary = Color3.fromRGB(80, 80, 80), -- Kept for now, maps to BackgroundTertiary or a button style
        -- Accent = Color3.fromRGB(255, 170, 0), -- Kept for now, maps to ThemeAccent
    },
    Fonts = {
        Display = { Font = Enum.Font.GothamBlack, Size = 36 },
        Headline = { Font = Enum.Font.GothamBold, Size = 28 },
        Title = { Font = Enum.Font.GothamBold, Size = 20 }, -- Was 22
        Subtitle = { Font = Enum.Font.GothamMedium, Size = 16 },
        Body = { Font = Enum.Font.Gotham, Size = 14 },          -- Was Default.Size = 16
        BodyBold = { Font = Enum.Font.GothamBold, Size = 14 },
        Button = { Font = Enum.Font.GothamBold, Size = 15 },    -- Was 16
        Caption = { Font = Enum.Font.Gotham, Size = 12 },
        InputText = { Font = Enum.Font.Gotham, Size = 14 }
    },
    ButtonStyles = {
        Primary = {
            BackgroundColor = "ThemePrimary",
            TextColor = "TextOnPrimary",
            BorderColor = "ThemePrimary",
            HoverBackgroundColor = Color3.fromRGB(21, 101, 192), -- Darker ThemePrimary
            HoverTextColor = "TextOnPrimary",
            PressedBackgroundColor = Color3.fromRGB(13, 71, 161), -- Even darker ThemePrimary
            PressedTextColor = "TextOnPrimary"
        },
        Secondary = {
            BackgroundColor = "BackgroundSecondary",
            TextColor = "TextPrimary",
            BorderColor = "Border",
            HoverBackgroundColor = Color3.fromRGB(55, 55, 57), -- Lighter BackgroundSecondary
            HoverTextColor = "TextPrimary",
            PressedBackgroundColor = Color3.fromRGB(70, 70, 72), -- Darker BackgroundSecondary (matches Border)
            PressedTextColor = "TextPrimary"
        },
        Accent = {
            BackgroundColor = "ThemeAccent",
            TextColor = "TextOnAccent",
            BorderColor = "ThemeAccent",
            HoverBackgroundColor = Color3.fromRGB(255, 179, 0), -- Darker ThemeAccent
            HoverTextColor = "TextOnAccent",
            PressedBackgroundColor = Color3.fromRGB(255, 160, 0), -- Even darker ThemeAccent
            PressedTextColor = "TextOnAccent"
        },
        Error = {
            BackgroundColor = "Error",
            TextColor = "TextOnPrimary", -- Assuming white text on red
            BorderColor = "Error",
            HoverBackgroundColor = Color3.fromRGB(211, 47, 47), -- Darker Error
            HoverTextColor = "TextOnPrimary",
            PressedBackgroundColor = Color3.fromRGB(198, 40, 40), -- Even darker Error
            PressedTextColor = "TextOnPrimary"
        },
        Quiet = { -- For less prominent actions, like a 'cancel' text button
            BackgroundColor = Color3.new(0,0,0), -- Fully transparent or nearly so
            BackgroundTransparency = 1,
            TextColor = "TextSecondary",
            BorderColor = Color3.new(0,0,0),
            BorderTransparency = 1,
            HoverBackgroundColor = "BackgroundTertiary",
            HoverBackgroundTransparency = 0.8,
            HoverTextColor = "TextPrimary",
            PressedBackgroundColor = "Border",
            PressedBackgroundTransparency = 0.7,
            PressedTextColor = "TextPrimary"
        }
    },
    -- General Metrics
    Metrics = {
        CornerRadiusSmall = UDim.new(0, 4),
        CornerRadiusMedium = UDim.new(0, 8),
        CornerRadiusLarge = UDim.new(0, 12),

        PaddingTiny = UDim.new(0, 2),
        PaddingSmall = UDim.new(0, 5),
        PaddingMedium = UDim.new(0, 10),
        PaddingLarge = UDim.new(0, 15),
        PaddingExtraLarge = UDim.new(0, 20),

        BorderThickness = 1, -- pixels

        IconSizeSmall = UDim2.new(0, 16, 0, 16),
        IconSizeMedium = UDim2.new(0, 24, 0, 24),
        IconSizeLarge = UDim2.new(0, 32, 0, 32),

        DefaultTransparency = 0, -- For opaque backgrounds
        HoverTransparencyModifier = -0.1, -- Makes color slightly darker/more opaque on hover
        PressedTransparencyModifier = -0.2, -- Makes color even more so on press

        ShadowElevation1 = {
            Color = Color3.fromRGB(0,0,0),
            Transparency = 0.8,
            Size = 4, -- Blur
            Offset = Vector2.new(0, 2)
        },
        ShadowElevation2 = {
            Color = Color3.fromRGB(0,0,0),
            Transparency = 0.7,
            Size = 8,
            Offset = Vector2.new(0, 4)
        }
    },

    BUTTON_HOVER_DURATION = 0.1, -- Faster hover
    DIALOG_ANIMATION_DURATION = 0.2 -- Faster dialog animations
}

return Constants