window.GAME_LEVELS = {
  "1": {
    "level_id": 1,
    "level_name": "Level 1: Basic Matching",
    "description": "Tests standard 3-bubble matching. Match 3 same-colored bubbles to pop them.",
    "max_shots": 30,
    "danger_row": 12,
    "target_score": 300,
    "allowed_colors": [
      0,
      1
    ],
    "layout_rows": [
      "RR..BB..",
      ".R...B.",
      "..R...B."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "10": {
    "level_id": 10,
    "level_name": "Level 10: Danger Threat",
    "description": "Tests lose condition when shot count is depleted on an uncleared board.",
    "max_shots": 15,
    "danger_row": 12,
    "target_score": 1000,
    "allowed_colors": [
      4,
      5,
      0,
      1
    ],
    "layout_rows": [
      "RRRRRRRR",
      "BBBBBBB",
      "GGGGGGGG",
      "YYYYYYY",
      "PPPPPPPP",
      "CCCCCCC",
      "RRRRRRRR",
      "BBBBBBB",
      "GGGGGGGG",
      "YYYYYYY"
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "11": {
    "level_id": 11,
    "world_id": 2,
    "level_name": "Level 11: Bomb Introduction",
    "description": "Meet the Bomb bubble! Hitting or matching near a bomb detonates all surrounding bubbles in a fiery blast.",
    "max_shots": 25,
    "danger_row": 12,
    "target_score": 500,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      1,
      2
    ],
    "layout_rows": [
      "RR..BB..",
      ".G...G.",
      "..GG...."
    ],
    "special_layout": {
      "1,3": 1
    }
  },
  "12": {
    "level_id": 12,
    "world_id": 2,
    "level_name": "Level 12: Rainbow Wilds",
    "description": "Rainbow bubbles are wild! They connect and match with any colored bubble cluster.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 600,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      1,
      3
    ],
    "layout_rows": [
      "RR....BB",
      ".Y....Y.",
      "..YYYY.."
    ],
    "special_layout": {
      "0,3": 2,
      "0,4": 2
    }
  },
  "13": {
    "level_id": 13,
    "world_id": 2,
    "level_name": "Level 13: Lightning Beam",
    "description": "Lightning bubbles discharge an electric surge that clears an entire horizontal row.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 700,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      1,
      4,
      5
    ],
    "layout_rows": [
      "PPPPPPPP",
      ".B...B.",
      "..CCCC.."
    ],
    "special_layout": {
      "0,3": 3
    }
  },
  "14": {
    "level_id": 14,
    "world_id": 2,
    "level_name": "Level 14: Stone Obstacles",
    "description": "Stone bubbles are sturdy obstacles. You cannot match them directly\u2014drop them or blow them up!",
    "max_shots": 22,
    "danger_row": 12,
    "target_score": 650,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      2
    ],
    "layout_rows": [
      "RR....RR",
      ".G....G.",
      "..GGGG.."
    ],
    "special_layout": {
      "0,3": 4,
      "0,4": 4
    }
  },
  "15": {
    "level_id": 15,
    "world_id": 2,
    "level_name": "Level 15: Frozen Ice Shells",
    "description": "Locked bubbles are encased in ice. Make a match adjacent to them to crack the shell free!",
    "max_shots": 25,
    "danger_row": 12,
    "target_score": 750,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      1,
      2,
      5
    ],
    "layout_rows": [
      "BB..GG..",
      ".C...C.",
      "..CCCC.."
    ],
    "special_layout": {
      "0,0": 5,
      "0,1": 5
    }
  },
  "16": {
    "level_id": 16,
    "world_id": 2,
    "level_name": "Level 16: Cavern Crossroads",
    "description": "Combine bombs and rainbow bubbles to clear branching crystal paths.",
    "max_shots": 22,
    "danger_row": 12,
    "target_score": 800,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      3,
      4
    ],
    "layout_rows": [
      "RR....YY",
      ".P...P.",
      "..PPPP.."
    ],
    "special_layout": {
      "0,3": 1,
      "1,3": 2
    }
  },
  "17": {
    "level_id": 17,
    "world_id": 2,
    "level_name": "Level 17: Ice & Lightning",
    "description": "Trigger a lightning blast through locked ice columns.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 850,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      1,
      2,
      5
    ],
    "layout_rows": [
      "GG....BB",
      ".C...C.",
      "..CCCC.."
    ],
    "special_layout": {
      "0,3": 3,
      "1,0": 5,
      "1,6": 5
    }
  },
  "18": {
    "level_id": 18,
    "world_id": 2,
    "level_name": "Level 18: Stone Guardian",
    "description": "Stone pillars guard the ceiling. Bank your shots around them to trigger a drop.",
    "max_shots": 18,
    "danger_row": 12,
    "target_score": 900,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      3,
      4
    ],
    "layout_rows": [
      "YY....YY",
      ".P...P.",
      "..RRRR.."
    ],
    "special_layout": {
      "0,2": 4,
      "0,5": 4
    }
  },
  "19": {
    "level_id": 19,
    "world_id": 2,
    "level_name": "Level 19: Geode Chamber",
    "description": "Multi-colored geode layers waiting for a well-placed rainbow wild.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 950,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      1,
      2,
      3
    ],
    "layout_rows": [
      "RR..BB..",
      ".G...Y.",
      "..RRGGBB"
    ],
    "special_layout": {
      "0,3": 2,
      "1,3": 1
    }
  },
  "2": {
    "level_id": 2,
    "level_name": "Level 2: Wall Bounce",
    "description": "Tests wall bounce navigation. Clear center blockers or bank off the walls.",
    "max_shots": 25,
    "danger_row": 12,
    "target_score": 400,
    "allowed_colors": [
      0,
      2
    ],
    "layout_rows": [
      "GG....GG",
      ".G....G",
      "..RRRR..",
      "..RR..."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "20": {
    "level_id": 20,
    "world_id": 2,
    "level_name": "Level 20: Crystal Heart",
    "description": "Boss stage of World 2: Clear the central crystal cluster protected by stone and ice rings.",
    "max_shots": 25,
    "danger_row": 12,
    "target_score": 1200,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      4,
      5,
      0,
      1
    ],
    "layout_rows": [
      "PP....CC",
      ".R...B.",
      "..PPPP.."
    ],
    "special_layout": {
      "0,3": 1,
      "0,4": 1,
      "1,1": 5,
      "1,5": 5,
      "2,2": 4,
      "2,5": 4
    }
  },
  "21": {
    "level_id": 21,
    "world_id": 3,
    "level_name": "Level 21: Sunken Canopy",
    "description": "Objective: Pop 6 Red bubbles to complete the woodland trial!",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 600,
    "objective_type": 1,
    "objective_target_count": 6,
    "objective_target_color": 0,
    "allowed_colors": [
      0,
      1,
      2
    ],
    "layout_rows": [
      "RR..RR..",
      ".B...B.",
      "..GGGG.."
    ],
    "special_layout": {
      "1,3": 2
    }
  },
  "22": {
    "level_id": 22,
    "world_id": 3,
    "level_name": "Level 22: Emerald Bloom",
    "description": "Objective: Pop 8 Green bubbles before ammo expires!",
    "max_shots": 22,
    "danger_row": 12,
    "target_score": 700,
    "objective_type": 1,
    "objective_target_count": 8,
    "objective_target_color": 2,
    "allowed_colors": [
      2,
      3,
      5
    ],
    "layout_rows": [
      "GG....GG",
      ".Y...C.",
      "..GGGG.."
    ],
    "special_layout": {
      "0,3": 3
    }
  },
  "23": {
    "level_id": 23,
    "world_id": 3,
    "level_name": "Level 23: Score Hunt",
    "description": "Objective: Score at least 1,000 points using high combos and avalanche drops!",
    "max_shots": 18,
    "danger_row": 12,
    "target_score": 1000,
    "objective_type": 2,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      1,
      3
    ],
    "layout_rows": [
      "RR....BB",
      ".Y.....",
      "..YYYY.."
    ],
    "special_layout": {
      "0,3": 1,
      "0,4": 1
    }
  },
  "24": {
    "level_id": 24,
    "world_id": 3,
    "level_name": "Level 24: Ancient Locks",
    "description": "Objective: Shatter 4 locked ice shells to free the canopy.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 850,
    "objective_type": 3,
    "objective_target_count": 4,
    "objective_target_color": -1,
    "allowed_colors": [
      1,
      4,
      5
    ],
    "layout_rows": [
      "PP....CC",
      ".B...B.",
      "..CCCC.."
    ],
    "special_layout": {
      "0,0": 5,
      "0,1": 5,
      "0,6": 5,
      "0,7": 5
    }
  },
  "25": {
    "level_id": 25,
    "world_id": 3,
    "level_name": "Level 25: Triple Threat",
    "description": "Bombs, lightning, and wild rainbows all in one challenging layout.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 1100,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      2,
      4
    ],
    "layout_rows": [
      "RR....GG",
      ".P...P.",
      "..PPPP.."
    ],
    "special_layout": {
      "0,2": 1,
      "0,5": 3,
      "1,3": 2
    }
  },
  "26": {
    "level_id": 26,
    "world_id": 3,
    "level_name": "Level 26: Stone Fortress",
    "description": "Shatter the stone perimeter using bank shots and explosive chain reactions.",
    "max_shots": 22,
    "danger_row": 12,
    "target_score": 1150,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      1,
      3,
      5
    ],
    "layout_rows": [
      "BB....YY",
      ".C...C.",
      "..CCCC.."
    ],
    "special_layout": {
      "0,2": 4,
      "0,5": 4,
      "1,3": 1
    }
  },
  "27": {
    "level_id": 27,
    "world_id": 3,
    "level_name": "Level 27: Purple Harvest",
    "description": "Objective: Pop 10 Purple bubbles amidst narrow corridors.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 1200,
    "objective_type": 1,
    "objective_target_count": 10,
    "objective_target_color": 4,
    "allowed_colors": [
      4,
      0,
      2
    ],
    "layout_rows": [
      "PP....PP",
      ".P...P.",
      "..PPPP.."
    ],
    "special_layout": {
      "0,3": 2
    }
  },
  "28": {
    "level_id": 28,
    "world_id": 3,
    "level_name": "Level 28: Avalanche Peak",
    "description": "Massive hanging structure with high-value drops and tight 16-shot ammo limit.",
    "max_shots": 16,
    "danger_row": 12,
    "target_score": 1300,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      1,
      3
    ],
    "layout_rows": [
      "RR....BB",
      ".Y...Y.",
      "..YYYY.."
    ],
    "special_layout": {
      "0,3": 1,
      "0,4": 1
    }
  },
  "29": {
    "level_id": 29,
    "world_id": 3,
    "level_name": "Level 29: Precision Labyrinth",
    "description": "Navigate tight geometric corridors with precision bank shots to trigger line clears.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 1400,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      1,
      2,
      4,
      5
    ],
    "layout_rows": [
      "GG....CC",
      ".B...P.",
      "..PPPP.."
    ],
    "special_layout": {
      "0,2": 3,
      "0,5": 3,
      "1,0": 5,
      "1,6": 5
    }
  },
  "3": {
    "level_id": 3,
    "level_name": "Level 3: Floating Anchor",
    "description": "Tests floating cluster detection. Popping the top red anchors will drop the blue bubbles.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 350,
    "allowed_colors": [
      0,
      1
    ],
    "layout_rows": [
      "RR......",
      ".R.....",
      "..BBBB..",
      "..BB..."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "30": {
    "level_id": 30,
    "world_id": 3,
    "level_name": "Level 30: Sunken Crown",
    "description": "Grand Master Finale: Free the Sunken Crown using bombs, lightning surges, and maximum combos!",
    "max_shots": 28,
    "danger_row": 12,
    "target_score": 2000,
    "objective_type": 0,
    "objective_target_count": 0,
    "objective_target_color": -1,
    "allowed_colors": [
      0,
      1,
      2,
      3,
      4,
      5
    ],
    "layout_rows": [
      "RR....BB",
      ".G...Y.",
      "..PPCC..",
      "..RR..."
    ],
    "special_layout": {
      "0,2": 1,
      "0,5": 1,
      "1,3": 2,
      "2,2": 4,
      "2,5": 4,
      "3,2": 5,
      "3,3": 5
    }
  },
  "4": {
    "level_id": 4,
    "level_name": "Level 4: Large Match",
    "description": "Tests large multi-bubble match detection with 4+ connected same-color bubbles.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 500,
    "allowed_colors": [
      2,
      3
    ],
    "layout_rows": [
      "GGGG....",
      "GGGG...",
      ".YYYY...",
      "..YY..."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "5": {
    "level_id": 5,
    "level_name": "Level 5: Color Spectrum",
    "description": "Tests all 6 bubble colors on the board simultaneously.",
    "max_shots": 35,
    "danger_row": 12,
    "target_score": 600,
    "allowed_colors": [
      0,
      1,
      2,
      3,
      4,
      5
    ],
    "layout_rows": [
      "RRGGBBYY",
      "PPCCRRB",
      "RRGGBBYY"
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "6": {
    "level_id": 6,
    "level_name": "Level 6: Precision Gap",
    "description": "Tests deep snapping and collision accuracy through narrow lateral corridors.",
    "max_shots": 25,
    "danger_row": 12,
    "target_score": 450,
    "allowed_colors": [
      5,
      3,
      2,
      0,
      1
    ],
    "layout_rows": [
      "BB....BB",
      "RR...RR",
      "GG....GG",
      "YY...YY",
      "..CCCC.."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "7": {
    "level_id": 7,
    "level_name": "Level 7: Avalanche Drop",
    "description": "Tests massive floating cluster drop after severing top yellow anchor bubbles.",
    "max_shots": 20,
    "danger_row": 12,
    "target_score": 800,
    "allowed_colors": [
      3,
      0,
      1,
      2
    ],
    "layout_rows": [
      "YY......",
      ".Y.....",
      "..RRRRRR",
      "..BBBBB",
      "..GGGGGG"
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "8": {
    "level_id": 8,
    "level_name": "Level 8: Tight Ammo",
    "description": "Tests low shot count limit requiring efficient matching in 6 shots.",
    "max_shots": 15,
    "danger_row": 12,
    "target_score": 300,
    "allowed_colors": [
      0,
      1
    ],
    "layout_rows": [
      "RR..BB..",
      ".R...B.",
      "..R...B."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  },
  "9": {
    "level_id": 9,
    "level_name": "Level 9: One Shot Win",
    "description": "Tests immediate win condition. Popping the top red anchors clears the whole board.",
    "max_shots": 10,
    "danger_row": 12,
    "target_score": 200,
    "allowed_colors": [
      0
    ],
    "layout_rows": [
      "RR......",
      ".B.....",
      "..BB...."
    ],
    "world_id": 1,
    "objective_type": 0,
    "target_count": 0,
    "target_color": -1,
    "special_layout": {}
  }
};
