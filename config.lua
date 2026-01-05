Config = {}

Config.Job = 'unemployed'

Config.Rewards = {
    dishwasher = {
        xpPerPlate = 2,
        moneyPerPlate = 20
    },
    waiter = {
        xpPerOrder = 8,
        moneyPerOrder = 50
    },
    chef = {
        xpPerDish = 12,
        moneyPerDish = 65
    }
}

Config.Levels = {
    [0] = { min = 0,   max = 100 },
    [1] = { min = 100, max = 250 },
    [2] = { min = 250, max = 500 },
    [3] = { min = 500, max = 900 },
    [4] = { min = 900, max = 1500 },
    [5] = { min = 1500, max = 2250 },
}

Config.Interactions = {
    manager = {
        ped = 'a_m_y_business_01',
        coords = vec4(128.0982, -1032.5967, 29.2771, 60.5347),
    },
    dishwashing = {
        label = 'Dishwasher',
        level = 0,
        spawnLocation = vec4(146.1335, -1053.7441, 22.9602, 346.0336),
        plates = {
            model = 'v_ret_fh_plate3',
            maxActive = 2,
            cleanTime = 5000,
            spawnInterval = 5000,
            storageLocation = vec3(147.6168, -1057.6761, 22.9602),
            locations = {
                vec4(142.4403, -1056.6649, 22.8628, 79.8893),
                vec4(145.6874, -1052.8224, 22.8157, 348.1210),
                vec4(148.8666, -1056.1104, 22.8143, 217.1726),
                vec4(146.0978, -1056.8864, 22.8621, 97.8544)
            }
        }
    },
    waiter = {
        label = 'Waiter',
        level = 2,
        spawnLocation = vec4(130.7412, -1055.9225, 22.9602, 66.3553),
        counterLocation = vec3(134.8620, -1055.5577, 23.2674),
        bar = {
            npcModels = {'a_m_y_hipster_01', 'a_f_y_hipster_01', 'a_m_y_business_02', 'a_f_m_business_02'},
            maxCustomers = 1,
            spawnInterval = 30000,
            orderTime = 5000,
            seats = {
                vec4(129.4826, -1052.9171, 22.9602, 159.8857),
            }
        },
        menu = {
            'Burger',
            'Pizza',
            'Salad',
            'Steak'
        }
    },
    chef = {
        label = 'Chef',
        level = 3,
        spawnLocation = vec4(146.5929, -1054.2546, 22.9602, 149.7773),
        kitchen = {
            cookingTime = 5000, 
            maxOrders = 3,
            orderInterval = 45000,
            stations = {
                main = vec3(135.1075, -1056.2097, 22.9602),
                grill = vec3(146.0823, -1055.8086, 22.8755),  
                oven = vec3(145.2761, -1060.9551, 22.9602),
                cuttingBoard = vec3(147.9288, -1053.6245, 22.9361), 
                prepTable = vec3(145.2508, -1056.3580, 22.8852),   
                assembly = vec3(143.7728, -1052.3916, 22.9979)     
            },
            dishes = {
                {
                    name = 'Burger', 
                    steps = {
                        {action = 'Cook Beef Patty', station = 'grill', anim = {dict = 'amb@prop_human_bbq@male@base', clip = 'base'}},
                        {action = 'Cut Burger Bun', station = 'prepTable', anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}},
                        {action = 'Slice Lettuce', station = 'cuttingBoard', anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}},
                        {action = 'Assemble Burger', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}}
                    }
                },
                {
                    name = 'Pizza', 
                    steps = {
                        {action = 'Prepare Dough', station = 'prepTable', anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}},
                        {action = 'Spread Sauce', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}},
                        {action = 'Add Cheese', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}},
                        {action = 'Bake Pizza', station = 'oven', anim = {dict = 'amb@prop_human_bbq@male@base', clip = 'base'}}
                    }
                },
                {
                    name = 'Steak', 
                    steps = {
                        {action = 'Season Meat', station = 'prepTable', anim = {dict = 'mp_common', clip = 'givetake1_a'}},
                        {action = 'Grill Steak', station = 'grill', anim = {dict = 'amb@prop_human_bbq@male@base', clip = 'base'}},
                        {action = 'Plate Steak', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}}
                    }
                },
                {
                    name = 'Pasta', 
                    steps = {
                        {action = 'Boil Pasta', station = 'grill', anim = {dict = 'amb@prop_human_bbq@male@base', clip = 'base'}},
                        {action = 'Prepare Sauce', station = 'prepTable', anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}},
                        {action = 'Add Cheese', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}},
                        {action = 'Plate Pasta', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}}
                    }
                },
                {
                    name = 'Salad', 
                    steps = {
                        {action = 'Chop Lettuce', station = 'cuttingBoard', anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}},
                        {action = 'Slice Tomatoes', station = 'cuttingBoard', anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}},
                        {action = 'Mix Salad', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}},
                        {action = 'Add Dressing', station = 'assembly', anim = {dict = 'mp_common', clip = 'givetake1_a'}}
                    }
                }
            }
        }
    }
}
