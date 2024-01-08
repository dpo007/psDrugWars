param (
    [switch]$SkipConsoleSizeCheck
)

########################
#region Class Definitions
##########################
class Drug {
    [string]$Name
    [string]$Code
    [string]$Description
    [int]$BasePrice
    [int[]]$PriceRange
    [float]$PriceMultiplier
    [int]$Quantity

    # Constructor that takes a drug name
    Drug([string]$Name) {
        $this.Name = $Name
        $this.Code = $script:DrugCodes.Keys | Where-Object { $script:DrugCodes[$_] -eq $Name }
        $this.Description = $script:DrugsInfo[$this.Code]['History']
        $this.PriceRange = $script:DrugsInfo[$this.Code]['PriceRange']
        $this.PriceMultiplier = 1.0
        $this.Quantity = 0
        $this.SetRandomBasePrice()
    }

    # Method to set the hidden BasePrice value to a random value from the drugs PriceRange, rounded to the nearest 10 dollars (Bankers' rounding).
    [void]SetRandomBasePrice() {
        $this.BasePrice = [int][math]::Round((Get-Random -Minimum $this.PriceRange[0] -Maximum $this.PriceRange[1]) / 10) * 10
    }

    # Calculate the price based on BasePrice and PriceMultiplier, rounded to the nearest 5 dollars (Bankers' rounding).
    [int]get_Price() {
        $price = [int][math]::Round($this.BasePrice * $this.PriceMultiplier / 5) * 5
        if ($price -lt 5) {
            $price = 5
        }
        return $price 
    }
}

class City {
    [string]$Name
    [Drug[]]$Drugs
    [int]$MaxDrugCount
    [string[]]$HomeDrugNames
    [float]$HomeDrugPriceMultiplier

    # Default constructor
    City() {
        # Drugs are assigned upon visiting the city (so they change each visit)
        $this.Drugs = @()

        # Assign 1 or 2 random 'Home Drugs' to each city
        $homeDrugCount = Get-Random -Minimum 1 -Maximum 3
        $this.HomeDrugNames = $script:DrugCodes.Keys | Get-Random -Count $homeDrugCount

        # Home Drugs are drugs that are always sold at a discount (if in stock).
        $this.HomeDrugPriceMultiplier = .80
    }

}

class Player {
    [int]$Cash
    [City]$City
    [Drug[]]$Drugs
    hidden [int]$Pockets
    [string[]]$Clothing
    [int]$GameDay
    [string]$Initials

    hidden [string[]]$starterClothes = @(
        'Bell-bottom pants',
        'Flannel shirt (buttoned Cholo-style)',
        '"I''m with Stupid ->" T-shirt',
        'Over-sized athletic jersey',
        'Pink Floyd T-shirt',
        'Smelly socks',
        'Smelly socks with a hole in them',
        'Terry-cloth bath robe',
        'Underwear hanging out',
        'Velour track suit',
        'Wife-beater'
    )

    # Default constructor
    Player() {
        $this.Drugs = @()
        $this.Clothing = $this.starterClothes | Get-Random
        $this.Pockets = 0
        $this.GameDay = 1
    }

    # FreePockets method returns the number of pockets minus the total Quntity of all Drugs
    [int]get_FreePocketCount() {
        $totalQuantity = 0
        $this.Drugs | ForEach-Object { $totalQuantity += $_.Quantity }
        return $this.Pockets - $totalQuantity
    }

    # Method to get pocket count
    [int]get_PocketCount() {
        return $this.Pockets
    }

    # Method to set pocket count
    [void]set_PocketCount([int]$Pockets) {
        $this.Pockets = $Pockets
    }

    # Method to adjust pocket count up or down
    [void]AdjustPocketCount([int]$Pockets) {
        if ($Pockets -lt 0) {
            # Remove specified number of pockets
            $this.Pockets -= $Pockets

            # Get a count of all drugs in the player's inventory
            $totalQuantity = 0
            $this.Drugs | ForEach-Object { $totalQuantity += $_.Quantity }

            # If the player has more drugs than pockets, remove some excess drugs
            if ($totalQuantity -gt $this.Pockets) {

                Write-Centered 'You don''t have enough pockets to hold all your drugs!' -ForegroundColor Yellow
                Start-Sleep -Seconds 2

                $difference = $totalQuantity - $this.Pockets

                # While the difference is greater than 0, cycle through the drugs in inventory, removing 1 of each until the difference is 0.
                while ($difference -gt 0) {
                    foreach ($drug in $this.Drugs) {
                        $this.RemoveDrugs($drug, 1)
                        Write-Centered ('You had to throw away 1 {0}.' -f $drug.Name) -ForegroundColor DarkRed
                        $difference -= 1
                        if ($difference -le 0) {
                            break
                        }
                    }
                }
            }
        }
        else {
            $this.Pockets += $Pockets
        }
    }

    # Method to add drugs to the player's Drugs collection.
    [void]AddDrugs([Drug]$Drug) {
        # Minimum Add is 1
        if ($Drug.Quantity -lt 1) {
            Write-Host 'You must add at least 1 of a drug.'
            return
        }

        # Check if there's enough free pockets
        if ($this.get_FreePocketCount() -ge $Drug.Quantity) {
            # If the player already has some of the drug, add the quantity to the existing drug, otherwise add the drug to the player's Drugs collection.
            $myMatchingDrug = $this.Drugs | Where-Object { $_.Name -eq $Drug.Name }
            if ($myMatchingDrug) {
                $myMatchingDrug.Quantity += $Drug.Quantity
            }
            else {
                $this.Drugs += $Drug
            }
        }
        else {
            Write-Host "Not enough free pockets to add this drug."
        }
    }

    # Method to remove drugs from the player's Drugs collection.
    [void]RemoveDrugs([Drug]$Drug, [int]$Quantity) {
        # If the player has some of the drug, remove the quantity from the existing drug, otherwise do nothing.
        $myMatchingDrug = $this.Drugs | Where-Object { $_.Name -eq $Drug.Name }
        if ($myMatchingDrug) {
            $myMatchingDrug.Quantity -= $Quantity
            if ($myMatchingDrug.Quantity -le 0) {
                # None left, remove the Drug object from the Drugs collection.
                $this.Drugs = $this.Drugs | Where-Object { $_.Name -ne $Drug.Name }
            }
        }
        else {
            Write-Host 'You don''t have any of that drug.'
        }
    }

    # Method to buy drugs.
    [void]BuyDrugs([Drug]$Drug) {
        # Get the drug from the city's drug list (if it's available)
        $cityDrug = $this.City.Drugs | Where-Object { $_.Name -eq $Drug.Name }

        # Use a switch statement to handle different conditions (run teh first block that's "True")
        switch ($true) {
            # If the drug is not available in the city, print a message and return
            (-not $cityDrug) {
                $wachoo = @('Whutchoo talkin'' about, Willis?', 'Are you high?', 'You''re trippin''!', 'You drunk?')
                Write-Host ('{0} {1} is not available in {2}.' -f (Get-Random -InputObject $wachoo), $Drug.Name, $this.City.Name)
                break
            }
            # If the quantity is less than 1, print a message and return
            ($Drug.Quantity -lt 1) {
                Write-Host ('You really trying to buy {0} drugs...?' -f $Drug.Quantity)
                $whoyou = @('M.C. Escher', 'Salvador Dali', 'David Blaine', 'Doug Henning')
                Write-Host ('Who are you? {0} or some shit?' -f (Get-Random -InputObject $whoyou))
                break
            }
            # If the drug is available and the quantity is valid, proceed to buy
            default {
                # Calculate the total price
                $totalPrice = $Drug.Quantity * $Drug.get_Price()
                # If the player doesn't have enough cash, print a message and return
                if ($totalPrice -gt $this.Cash) {
                    Write-Host ('You don''t have enough cash to buy that much {0}.' -f $Drug.Name)
                    break
                }
                # If the quantity being bought is greater than the number of free pockets, print a message and return
                $freePockets = $this.get_FreePocketCount()
                if ($Drug.Quantity -gt $freePockets) {
                    Write-Host ('You don''t have enough free pockets to hold that much {0}.' -f $Drug.Name)
                    break
                }
                # If the player has enough cash and free pockets, buy the drugs
                $this.Cash -= $totalPrice
                Write-Host ('You bought {0} {1} for ${2}.' -f $Drug.Quantity, $Drug.Name, $totalPrice)
                $this.AddDrugs($Drug)
                
            }
        }
        # Pause for 3 seconds before returning
        Start-Sleep 3
    }

    # Method to sell drugs.
    [void]SellDrugs([Drug]$Drug, [int]$Quantity) {
        
        # Look up the drug by name in the current City's drug list.
        $cityDrug = $this.City.Drugs | Where-Object { $_.Name -eq $Drug.Name }
        
        # Calculate the total price (using the city's price for the drug)
        $totalPrice = $cityDrug.get_Price() * $Quantity

        # Check if the player has enough quantity of the drug
        $drugToSell = $this.Drugs | Where-Object { $_.Name -eq $Drug.Name }
        if ($drugToSell.Quantity -lt $Quantity) {
            Write-Host ('You don''t have enough {0} to sell.' -f $Drug.Name)
            return
        }

        # If the player has enough quantity of the drug, sell the drugs
        $this.RemoveDrugs($Drug, $Quantity)
        $this.Cash += $totalPrice
        Write-Host ('You sold {0} {1} for ${2}.' -f $Quantity, $Drug.Name, $totalPrice)
    }

    # Method to add items to the player's Clothing collection.
    [bool]AddClothing([string]$Item) {
        # If the player already has the item, return false
        if ($this.Clothing -contains $Item) {
            return $false
        }
        # Otherwise, add the item to the player's Clothing and return true.
        else {
            $this.Clothing += $Item
            return $true
        }
    }

    # Method to change base outfit.
    [string]ChangeOutfit() {
        $currentStarterClothes = $this.starterClothes | Where-Object { $this.Clothing -contains $_ }

        # Remove any clothing that is in the starterClothes list.
        $this.Clothing = $this.Clothing | Where-Object { $this.starterClothes -notcontains $_ }

        # Put on a random new one, that isn't in $currentStarterClothes
        $newClothing = $this.starterClothes | Where-Object { $_ -notin $currentStarterClothes } | Get-Random

        # Add the new clothing to the top of the list
        $otherClothes = $this.Clothing
        $this.Clothing = @($newClothing)

        # Add the other clothing back to the list (unless it's null)
        if ($otherClothes) {
            $this.Clothing += $otherClothes
        }

        # Return the new clothing
        return $newClothing
    }
}
###########################
#endregion Class Definitions
#############################

##########################################
#region Define Script-Wide Lists and Tables
############################################
# Define drugs names and codes
$script:DrugCodes = @{
    'AD' = 'Angel Dust'
    'CD' = 'Codeine'
    'CN' = 'Cocaine'
    'CK' = 'Crack'
    'DM' = 'DMT'
    'EC' = 'Ecstasy'
    'FT' = 'Fentanyl'
    'HN' = 'Heroin'
    'HS' = 'Hash'
    'KM' = 'Ketamine'
    'LD' = 'LSD'
    'LU' = 'Ludes'
    'MC' = 'Mescaline'
    'MN' = 'Morphine'
    'MT' = 'Meth'
    'OP' = 'Opium'
    'OX' = 'Oxy'
    'PA' = 'Peyote'
    'PO' = 'Poppers'
    'RT' = 'Ritalin'
    'SH' = 'Shrooms'
    'SP' = 'Speed'
    'VI' = 'Vicodin'
    'WD' = 'Weed'
    'XN' = 'Xanax'
}

# Define information about each drug
$script:DrugsInfo = @{
    'AD' = @{
        'Name'        = 'Angel Dust'
        'StreetNames' = @('PCP', 'Sherm', 'Embalming Fluid')
        'History'     = 'Developed as a dissociative anesthetic, Angel Dust gained popularity in the 1960s. Discontinued for medical use due to its unpredictable and severe side effects.'
        'Effects'     = 'Hallucinations, distorted perceptions of reality, increased strength, and a dissociative state.'
        'PriceRange'  = @(500, 2000)
    }
    'CD' = @{
        'Name'        = 'Codeine'
        'StreetNames' = @('Lean', 'Purple Drank', 'Sizzurp')
        'History'     = 'Codeine is an opiate used for pain relief. It has been used recreationally, often mixed with soda and candy, particularly in hip-hop culture.'
        'Effects'     = 'Euphoria, relaxation, and mild sedation.'
        'PriceRange'  = @(20, 150)
    }
    'CN' = @{
        'Name'        = 'Cocaine'
        'StreetNames' = @('Coke', 'Blow', 'Snow')
        'History'     = 'Derived from coca plants, cocaine became popular in the 1970s and 1980s as a recreational stimulant. Its use is associated with a high risk of addiction.'
        'Effects'     = 'Increased energy, alertness, and euphoria.'
        'PriceRange'  = @(100, 500)
    }
    'CK' = @{
        'Name'        = 'Crack'
        'StreetNames' = @('Freebase', 'Rock', 'Base')
        'History'     = 'Crack cocaine is a crystallized form of cocaine. It emerged in the 1980s, contributing to the "crack epidemic" in the United States.'
        'Effects'     = 'Intense, short-lived euphoria, increased heart rate, and heightened alertness.'
        'PriceRange'  = @(50, 300)
    }
    'DM' = @{
        'Name'        = 'DMT'
        'StreetNames' = @('Dimitri', 'Businessman''s Trip')
        'History'     = 'DMT is a naturally occurring psychedelic compound found in certain plants. Its use in shamanic rituals dates back centuries.'
        'Effects'     = 'Intense, short-lasting hallucinations, a sense of entering otherworldly realms.'
        'PriceRange'  = @(100, 1000)
    }
    'EC' = @{
        'Name'        = 'Ecstasy'
        'StreetNames' = @('MDMA', 'Molly', 'E', 'X')
        'History'     = 'Originally used in psychotherapy, ecstasy gained popularity in the 1980s as a recreational drug.'
        'Effects'     = 'Enhanced sensory perception, increased empathy, and heightened emotions.'
        'PriceRange'  = @(5, 50)
    }
    'FT' = @{
        'Name'        = 'Fentanyl'
        'StreetNames' = @('China White', 'Apache', 'Dance Fever')
        'History'     = 'Developed as a potent painkiller, fentanyl has been linked to a surge in opioid-related overdoses due to its high potency.'
        'Effects'     = 'Intense euphoria, drowsiness, and respiratory depression.'
        'PriceRange'  = @(100, 500)
    }
    'HN' = @{
        'Name'        = 'Heroin'
        'StreetNames' = @('Smack', 'Junk', 'H')
        'History'     = 'Derived from morphine, heroin was initially marketed as a non-addictive alternative. Its recreational use rose in the mid-20th century.'
        'Effects'     = 'Euphoria, sedation, pain relief.'
        'PriceRange'  = @(50, 300)
    }
    'HS' = @{
        'Name'        = 'Hash'
        'StreetNames' = @('Hashish', 'Hash Oil', 'Dabs')
        'History'     = 'Hash is a concentrated form of cannabis resin. It has a long history of use in various cultures for spiritual and recreational purposes.'
        'Effects'     = 'Relaxation, euphoria, altered perception of time.'
        'PriceRange'  = @(10, 100)
    }
    'KM' = @{
        'Name'        = 'Ketamine'
        'StreetNames' = @('Special K', 'K', 'Vitamin K')
        'History'     = 'Initially used as an anesthetic, ketamine gained popularity as a recreational drug with dissociative effects.'
        'Effects'     = 'Hallucinations, dissociation, altered perception of time and space.'
        'PriceRange'  = @(50, 500)
    }
    'LD' = @{
        'Name'        = 'LSD'
        'StreetNames' = @('Acid', 'Tabs', 'Blotter')
        'History'     = 'Discovered in the 1930s, LSD became popular in the 1960s counter-culture. It''s known for its profound psychedelic effects.'
        'Effects'     = 'Hallucinations, altered perception of reality, heightened sensory experiences.'
        'PriceRange'  = @(50, 300)
    }
    'LU' = @{
        'Name'        = 'Ludes'
        'StreetNames' = @('Quaaludes', 'Disco Biscuits')
        'History'     = 'Methaqualone, commonly known as Quaaludes, was a sedative-hypnotic drug popular in the 1970s. It was later classified as a controlled substance.'
        'Effects'     = 'Muscle relaxation, sedation, euphoria.'
        'PriceRange'  = @(100, 800)
    }
    'MC' = @{
        'Name'        = 'Mescaline'
        'StreetNames' = @('Peyote', 'Buttons', 'Cactus')
        'History'     = 'Mescaline is a naturally occurring psychedelic found in certain cacti, notably peyote. It has been used in Native American rituals for centuries.'
        'Effects'     = 'Visual hallucinations, altered perception, and enhanced sensory experiences.'
        'PriceRange'  = @(50, 500)
    }
    'MN' = @{
        'Name'        = 'Morphine'
        'StreetNames' = @('Dreamer', 'Mister Blue')
        'History'     = 'Derived from opium, morphine has been used for pain relief since the 19th century. It remains a powerful opioid analgesic.'
        'Effects'     = 'Pain relief, euphoria, sedation.'
        'PriceRange'  = @(50, 300)
    }
    'MT' = @{
        'Name'        = 'Meth'
        'StreetNames' = @('Crystal', 'Ice', 'Glass')
        'History'     = 'Methamphetamine, a potent stimulant, gained popularity for recreational use and as an illicit substance in the mid-20th century.'
        'Effects'     = 'Increased energy, alertness, euphoria.'
        'PriceRange'  = @(50, 500)
    }
    'OP' = @{
        'Name'        = 'Opium'
        'StreetNames' = @('Dopium', 'Chinese Tobacco', 'Midnight Oil')
        'History'     = 'Opium has a long history of use dating back centuries. It was widely used for medicinal and recreational purposes, leading to addiction issues.'
        'Effects'     = 'Pain relief, relaxation, euphoria.'
        'PriceRange'  = @(100, 800)
    }
    'OX' = @{
        'Name'        = 'Oxy'
        'StreetNames' = @('Oxycodone', 'Hillbilly Heroin', 'OxyContin')
        'History'     = 'Oxycodone, commonly known as Oxy, is a prescription opioid. It became widely abused for its pain-relieving and euphoric effects.'
        'Effects'     = 'Pain relief, relaxation, euphoria.'
        'PriceRange'  = @(50, 300)
    }
    'PA' = @{
        'Name'        = 'Peyote'
        'StreetNames' = @('Mescaline', 'Buttons', 'Cactus')
        'History'     = 'Peyote is a small, spineless cactus containing mescaline. It has been used in Native American religious ceremonies for centuries.'
        'Effects'     = 'Visual hallucinations, altered perception, and enhanced sensory experiences.'
        'PriceRange'  = @(100, 800)
    }
    'PO' = @{
        'Name'        = 'Poppers'
        'StreetNames' = @('Rush', 'Locker Room', 'Snappers')
        'History'     = 'Poppers are a type of alkyl nitrite inhalant. They have been used recreationally, especially in club and party scenes, for their brief but intense effects.'
        'Effects'     = 'Head rush, warm sensations, and intensified sensory experiences.'
        'PriceRange'  = @(5, 50)
    }
    'RT' = @{
        'Name'        = 'Ritalin'
        'StreetNames' = @('Rids', 'Vitamin R', 'Skittles')
        'History'     = 'Ritalin, or methylphenidate, was developed in the 1950s as a treatment for attention deficit hyperactivity disorder (ADHD). FDA-approved, it has since been prescribed for ADHD and narcolepsy.'
        'Effects'     = 'Stimulant effects include increased focus, alertness, and energy.'
        'PriceRange'  = @(5, 50)
    }
    'SH' = @{
        'Name'        = 'Shrooms'
        'StreetNames' = @('Magic Mushrooms', 'Psilocybin', 'Caps')
        'History'     = 'Psychedelic mushrooms, or shrooms, have been used in various cultures for their hallucinogenic properties. They gained popularity in the counterculture movements of the 1960s.'
        'Effects'     = 'Altered perception, visual hallucinations, introspective experiences.'
        'PriceRange'  = @(20, 200)
    }
    'SP' = @{
        'Name'        = 'Speed'
        'StreetNames' = @('Amphetamine', 'Uppers', 'Dexies')
        'History'     = 'Amphetamines have a long history of medical use and gained popularity as stimulants in the mid-20th century.'
        'Effects'     = 'Increased energy, alertness, heightened focus.'
        'PriceRange'  = @(50, 500)
    }
    'VI' = @{
        'Name'        = 'Vicodin'
        'StreetNames' = @('Hydro', 'Vikes', 'Watsons')
        'History'     = 'Vicodin is a combination of hydrocodone and acetaminophen used for pain relief. It has been widely prescribed but is associated with the risk of addiction.'
        'Effects'     = 'Pain relief, relaxation, mild euphoria.'
        'PriceRange'  = @(100, 800)
    }
    'WD' = @{
        'Name'        = 'Weed'
        'StreetNames' = @('Marijuana', 'Cannabis', 'Pot')
        'History'     = 'Cannabis has been used for various purposes for thousands of years. It gained popularity for recreational use in the 20th century.'
        'Effects'     = 'Relaxation, euphoria, altered sensory perception.'
        'PriceRange'  = @(10, 100)
    }
    'XN' = @{
        'Name'        = 'Xanax'
        'StreetNames' = @('Bars', 'Benzos', 'Zannies')
        'History'     = 'Xanax, a benzodiazepine, is prescribed for anxiety. Its recreational use has become a concern due to the risk of dependence.'
        'Effects'     = 'Relaxation, sedation, anti-anxiety effects.'
        'PriceRange'  = @(50, 300)
    }
}

# Define available cities
$script:CityNames = @(
    "Acapulco, Mexico",
    "Amsterdam, Netherlands",
    "Bangkok, Thailand",
    "Hong Kong, China",
    "Istanbul, Turkey",
    "Lisbon, Portugal",
    "London, UK",
    "Marseilles, France",
    "Medellin, Colombia",
    "Mexico City, Mexico",
    "Miami, USA",
    "Marrakesh, Morocco",
    "New York City, USA",
    "Panama City, Panama",
    "Phuket, Thailand",
    "San Francisco, USA",
    "Sydney, Australia",
    "Tehran, Iran",
    "Tijuana, Mexico",
    "Toronto, Canada",
    "Vancouver, Canada"
)

# Define random events
$script:RandomEvents = @(
    @{
        "Name"        = "Busted"
        "Description" = 'You were busted by the cops!'
        "Effect"      = {    
            Start-Sleep -Seconds 3
            # If player has no drugs on them, the cops leave them alone
            if ($script:Player.Drugs.Count -eq 0) {
                Write-Centered 'You were searched, but you didn''t have any drugs on you!'
                Write-Host
                Write-Centered 'The cops let you go with a warning.' -ForegroundColor DarkGreen
                
                if ($script:Player.Cash -gt 50) {
                    Start-Sleep -Seconds 2
                    # Cops let you go, but take 5% of your cash
                    Write-Centered '...after a bit of a shake-down.' -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                    $loss = [int]([math]::Round($script:Player.Cash * 0.05))
                    $script:Player.Cash = $script:Player.Cash - $loss
                    Write-Host
                    Write-Centered ('They took ${0}!' -f $loss) -ForegroundColor DarkRed
                }
                
                Start-Sleep -Seconds 3
                return
            }

            # Calculate the bust chance. The base chance is 0%, and it increases by 5% for each $1000 the player has. Capped at 60%.
            [float]$bustChance = 0.0
            if ($script:Player.Cash -gt 0) {
                $bustChance = [Math]::Min($script:Player.Cash / 1000 * 0.05, 0.6)
            }

            # Generate a random decimal number between 0 and 1
            [float]$randomNumber = Get-Random -Minimum 0.0 -Maximum 1.0
            # If the random number is less than or equal to the bust chance, the cops bust the player
            if ($randomNumber -le $bustChance) {
                Write-Centered 'You spent the night in jail and lost all your drugs.' -ForegroundColor Red
                # Remove all drugs from the player's possession
                $script:Player.Drugs = @()
                # Increment the game day
                AdvanceGameDay -SkipPriceUpdate
            }
            else {
                # Create an array of messages
                $messages = @(
                    'They searched you, but you got away!',
                    'You were searched, but managed to slip away!',
                    'They tried to catch you, but you were too quick!',
                    'You were almost caught, but you escaped!',
                    'They attempted to search you, but you evaded them!',
                    'You narrowly avoided being searched!',
                    'They let you go with a warning!',
                    'You played hide and seek with the search party, and you won!',
                    'You turned the search into a dance-off and moonwalked out of trouble!',
                    'They tried to catch you, but you hit them with your "Invisible Cloak of Inconspicuousness"(tm)!',
                    'You transformed the search into a magic show and disappeared in a puff of glitter!',
                    'You were almost caught, but you executed the perfect ninja smoke bomb escape!',
                    'They attempted to search you, but you pulled out a trombone and started a parade distracting them!',
                    'You narrowly avoided being searched by unleashing your inner contortionist and slipping through their fingers!',
                    'They let you go with a warning, probably because they were impressed by your interpretive dance routine!'       
                )

                # Select a random message
                $message = Get-Random -InputObject $messages

                # Display the message
                Write-Centered $message -ForegroundColor DarkGreen
            }

            Start-Sleep -Seconds 3
        }
    },
    @{
        "Name"        = "Flash Back"
        "Description" = "You trip out and lose a day!"
        "Effect"      = {
            Tripout
            AdvanceGameDay -SkipPriceUpdate
        }
    },
    @{
        "Name"        = "Marrakesh Express"
        "Description" = "The Marrakesh Express has arrived in town!"
        "Effect"      = {
            # Add some random "Hash" Drugs to the player's inventory, if they already have Hash, just add to its quantity.
            $giveAwayQuantity = Get-Random -Minimum 5 -Maximum 26
            Write-Centered ('They''re giving out {0} pockets of free Hash!' -f $giveAwayQuantity)
            Write-Host

            # If they have free pockets to hold the Hash, add as much to their inventory as possible.
            if ($script:Player.get_FreePocketCount() -ge 1) {
                if ($script:Player.get_FreePocketCount() -lt $giveAwayQuantity) {
                    Write-Centered ('You only have room for {0} pockets of free Hash.' -f $script:Player.get_FreePocketCount()) -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    Write-Centered 'But that''s still better than a kick in the ass''! :)'
                    $giveAwayQuantity = $script:Player.get_FreePocketCount()
                }

                $freeHash = $script:Player.Drugs | Where-Object { $_.Name -eq 'Hash' }
                if ($freeHash) {
                    $freeHash.Quantity += $giveAwayQuantity
                }
                else {
                    $freeHash = [Drug]::new('Hash')
                    $freeHash.Quantity = $giveAwayQuantity
                    $script:Player.AddDrugs($freeHash)
                }

                Write-Centered ('Filled {0} pockets with free Hash!' -f $giveAwayQuantity) -ForegroundColor DarkGreen
            }
            else {
                Write-Centered 'Bummer! You don''t have any empty pockets to hold the free Hash.'
                Start-Sleep -Seconds 3
                Write-Host
                if ((Write-BlockLetters '** BURN!! **' -ForegroundColor Black -BackgroundColor DarkRed -Align Center -VerticalPadding 1) -eq $false) {
                    Write-Centered ' ' -BackgroundColor DarkRed
                    Write-Centered '** BURN!! **' -ForegroundColor Black -BackgroundColor DarkRed
                    Write-Centered ' ' -BackgroundColor DarkRed
                }
                Start-Sleep -Seconds 2
            }
        }
    },
    @{
        "Name"        = "Bad Batch"
        "Description" = "You got a bad batch of drugs. You lose 10% of your cash trying to get rid of it."
        "Effect"      = {
            # Calculate 10% of the player's cash, rounded to the nearest dollar
            $loss = [int]([math]::Round($script:Player.Cash * 0.10))
            # Subtract the loss from the player's cash.
            $script:Player.Cash -= $loss

            Start-Sleep -Seconds 2
            Write-Host
            Write-Centered ('You lost ${0}.' -f $loss) -ForegroundColor DarkRed
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Someone's Wallet"
        "Description" = "You found a wallet full of cash laying in the gutter!"
        "Effect"      = {
            $gain = Get-Random -Minimum 100 -Maximum 501
            # Round the gain to the nearest 10 (Bankers' rounding).
            $gain = [math]::Round($gain / 10) * 10
            $script:Player.Cash += $gain

            Start-Sleep -Seconds 2
            Write-Host
            Write-Centered ('NICE! You gained ${0}.' -f $gain) -ForegroundColor DarkGreen
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Found Vape Pen"
        "Description" = "You found a vape pen on the ground. Do you want to use it? (Y/N)"
        "Effect"      = {
            # Wait for user to press a valid key
            $choices = @('Y', 'N')
            $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
            while (-not $choices.Contains($choice)) {
                $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
            }
            if ($choice -eq 'Y' ) {
                $experience = Get-Random -Minimum 1 -Maximum 10
                if ($experience -le 3) {
                    Write-Centered 'Uh oh!' -ForegroundColor DarkGreen
                    Start-Sleep -Seconds 2
                    Write-Centered 'What was in that thing?!'
                    Start-Sleep -Seconds 1
                    Tripout
                    Write-Centered 'You tripped out hard and lost a day!'
                    AdvanceGameDay -SkipPriceUpdate
                }
                else {
                    Start-Sleep -Milliseconds 500
                    Write-Centered 'Puff...'
                    Start-Sleep -Milliseconds 500
                    Write-Centered 'Puff...'
                    Start-Sleep -Seconds 2
                    $randomScore = Get-Random -Minimum 1 -Maximum 12
                    switch ($randomScore) {
                        { $_ -le 3 } {
                            Write-Centered ('Dude, bummer! Only {0}/10 - Harsh hit. Not exactly riding the good vibes, you know?' -f $randomScore)
                        }
                        { $_ -gt 3 -and $_ -le 6 } {
                            Write-Centered ('Hey cosmic traveler! {0}/10 - Decent hit. Average buzz, man.' -f $randomScore)
                        }
                        { $_ -gt 6 -and $_ -le 9 } {
                            Write-Centered ('Far out, dude! {0}/10 - Good hit. Nice buzz flowing through your soul.' -f $randomScore)
                        }
                        { $_ -gt 9 } {
                            Write-Centered ('Whoa, enlightenment achieved! {0}/10 - Amazing hit. Best vape ever, man!' -f $randomScore)
                        }
                        { $_ -gt 10 } {
                            Write-Host
                            Write-Centered ('You got so damn high, you actually GAINED A DAY!') -ForegroundColor Yellow
                            $script:GameDays++                          
                            Start-Sleep -Milliseconds 750
                            Write-Centered ('You now have {0} days to make as much cash as possible.' -f $script:GameDays) -ForegroundColor DarkGreen
                        }
                    }
                    
                }
            }
            else {
                Write-Centered 'You decided not to use the vape pen, and instead sell it to some skid for $5.'
                $script:Player.Cash += 5
            }
        }
    },
    @{
        "Name"        = "Cargo Pants"
        "Description" = "Groovy, man! You stumbled upon these cosmic cargo pants, packed with pockets for all your trippy treasures!"
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            if ($script:Player.AddClothing('Cargo Pants')) {
                $extraPockets = 20
                $script:Player.AdjustPocketCount($extraPockets)
                Write-Centered ('Far out! You''ve now got {0} extra pockets! Carryin'' more of your magic stash just got easier.' -f $extraPockets) -ForegroundColor DarkGreen
            }
            else {
                Write-Centered 'You already have a pair of cosmic cargo pants. You decide to sell these for $20.'
                $script:Player.Cash += 20
            }
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Hemp Backpack"
        "Description" = "Whoa, dude! Check out this Zen hemp backpack! It's like, totally eco-friendly and has space for all your good vibes and herbal remedies."
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            if ($script:Player.AddClothing('Hemp Backpack')) {
                $extraPockets = 50
                $script:Player.AdjustPocketCount($extraPockets)
                Write-Centered ('Far out! You''ve now got {0} extra pockets! Carryin'' more of your magic stash just got easier.' -f $extraPockets) -ForegroundColor DarkGreen
            }
            else {
                Write-Centered 'You already have a Zen hemp backpack. You decide to sell this one for $50.'
                $script:Player.Cash += 50
            }
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Tie-dyed Poncho"
        "Description" = "Far-out find, man! You snagged a psychedelic tie-dyed hemp poncho. It's like wearing a kaleidoscope of good vibes!"
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            if ($script:Player.AddClothing('Hemp Poncho')) {
                $extraPockets = 10
                $script:Player.AdjustPocketCount($extraPockets)
                Write-Centered ('Trippy, right? This tie-dyed hemp poncho adds {0} extra pockets to your cosmic wardrobe. Carry on, peace traveler.' -f $extraPockets) -ForegroundColor DarkGreen
            }
            else {
                Write-Centered 'You already have a tie-dyed hemp poncho. You decide to sell this one for $10.'
                $script:Player.Cash += 10
            }
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Fanny Pack"
        "Description" = "Radical, dude! You found a totally tubular fanny pack. It's compact, convenient, and has room for all your gnarly gear."
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            if ($script:Player.AddClothing('Fanny Pack')) {
                $extraPockets = 15
                $script:Player.AdjustPocketCount($extraPockets)
                Write-Centered ('Awesome! You''ve now got {0} extra pockets! Storing your stuff just got a whole lot easier.' -f $extraPockets) -ForegroundColor DarkGreen
            }
            else {
                Write-Centered 'You already have a fanny pack. You decide to sell this one for $15.'
                $script:Player.Cash += 15
            }
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Fishing Vest"
        "Description" = "Whoa, you've discovered a far-out fishing vest! It's got a whole whack of pockets for all your ""fishing gear""."
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            if ($script:Player.AddClothing('Fishing Vest')) {
                $extraPockets = 75
                $script:Player.AdjustPocketCount($extraPockets)
                Write-Centered ('Incredible! You''ve now got {0} extra pockets! You''ll never run out of storage space.' -f $extraPockets) -ForegroundColor DarkGreen
            }
            else {
                Write-Centered 'You already have a fishing vest. You decide to sell this one for $75.'
                $script:Player.Cash += 75
            }
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Fence Fumble"
        "Description" = "Uh-oh! You tried to impressively hop a fence to escape a shady-looking character, but your acrobatics didn't quite go as planned."
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            if ($script:Player.get_PocketCount() -gt 0) {
                $lostPockets = Get-Random -Minimum 1 -Maximum 4
                $script:Player.AdjustPocketCount(-$lostPockets)
                Write-Centered ('Yikes! You lost {0} pockets in the fence fumble fiasco. Perhaps stealth is more your style.' -f $lostPockets) -ForegroundColor DarkRed
            }
            else {
                Write-Centered 'Phew! Luckily, you had no pockets to lose. Maybe next time stick to a less athletic escape plan, dumpy.'
            }
            Start-Sleep -Seconds 2
        }
    },    
    @{
        "Name"        = "Lemonade Stand"
        "Description" = "Wandering through the gritty streets of Skid-Row, your eyes catch a peculiar sight - a little girl gleefully running a lemonade stand. But, as you approach, you realize this stand has a mysterious twist!"
        "Effect"      = {
            Start-Sleep -Seconds 3
            Write-Host
            $extraDrug = $script:GameDrugs | Get-Random
            # Pick 5 or 10 at random
            $extraDrug.Quantity = Get-Random -InputObject @(5, 10)

            $randomNumber = Get-Random -Minimum 1 -Maximum 101
            if ($script:Player.Cash -gt 2500 -and $randomNumber -le 20) {
                # 20% chance of getting mugged for 25-50% of your cash
                $muggedAmount = [Math]::Floor((Get-Random -Minimum ($script:Player.Cash * 0.25) -Maximum ($script:Player.Cash * 0.5)) / 10) * 10
                $script:Player.Cash -= $muggedAmount
                Write-Centered ('That''s no MF''ing kid!')
                Write-Centered ('That dwarf hustler at the Skid-Row Lemonade Stand just pulled a blade and mugged yo'' ass for {0} cash!' -f $muggedAmount) -ForegroundColor Red
            }
            else {
                Write-Centered ('Whoa! The enchanting little hustler at the Skid-Row Lemonade Stand just hooked you up with {0} pockets of {1}!' -f $extraDrug.Quantity, $extraDrug.Name) -ForegroundColor DarkGreen
                Write-Centered ('Your spirit is now a little more... unconventional!')
                $script:Player.AddDrugs($extraDrug)
            }
        }
    },    
    @{
        "Name"        = "Pocket Portal"
        "Description" = "You stumble upon a mysterious portal while high. Curiosity gets the better of you, and you step through!"
        "Effect"      = {
            Write-Centered 'Whoa, man! This portal takes you to a pocket dimension of infinite possibilities!'
            Start-Sleep -Seconds 3
            Write-Host
            $choice = Get-Random -Minimum 1 -Maximum 5
            $pocketCost = 10
            switch ($choice) {
                1 {
                    $extraPockets = 75
                    $extraPocketsCost = $pocketCost * $extraPockets
                    Write-Centered ('You encounter a cosmic, drugged-out vendor selling magical pockets.')
                    Write-Centered ('Spend ${0} to get {1} extra pockets? (Y/N)' -f $extraPocketsCost, $extraPockets)
                    if ($script:Player.Cash -ge $extraPocketsCost) {
                        # Wait for user to press a valid key
                        $choices = @('Y', 'N')
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        while (-not $choices.Contains($choice)) {
                            $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        }
                        if ($choice -eq 'Y') {
                            $script:Player.Cash -= $extraPocketsCost
                            $script:Player.AdjustPocketCount($extraPockets)
                            Write-Centered ('You made a wise investment and gained {0} extra pockets!' -f $extraPockets) -ForegroundColor DarkGreen
                        }
                        else {
                            Write-Centered 'You decide not to spend your cash, and the cosmic vendor fades away. No extra pockets for you.'
                        }
                    }
                    else {
                        Write-Centered 'You don''t have enough cash to buy the magical pockets. The cosmic vendor disappears in disappointment. No extra pockets for you.' -ForegroundColor Red
                    }
                }
                2 {
                    Write-Centered 'You meet a luded-out pocket guru who offers to enhance your inner pocket energy.' Write-Centered 'Meditate for a chance to gain 10 extra pockets? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        Write-Centered 'Meditating... ' -NoNewline
                        Start-Sleep -Seconds 3
                        Write-Centered 'Ohhhmmmmmm...'
                        Start-Sleep -Seconds 3
                        Write-Host
                        $success = Get-Random -Minimum 0 -Maximum 2
                        if ($success -eq 1) {
                            $script:Player.AdjustPocketCount(10)
                            Write-Centered 'After a deep meditation session, you feel your inner pocket energy expand. You gained 10 extra pockets!' -ForegroundColor DarkGreen
                        }
                        else {
                            Write-Centered 'Your meditation doesn''t quite hit the mark, and you gain no extra pockets. Bummer, man.'
                        }
                    }
                    else {
                        Write-Centered 'You decide not to meditate, and the pocket guru drifts away into the cosmic unknown. No extra pockets for you.'
                    }
                }
                3 {
                    if ($script:Player.get_PocketCount() -lt 5) {
                        Write-Centered 'You see a DMT-induced alien shaman, but they''re uninterested in playing a game with someone who doesn''t even have 5 pockets. No extra pockets for you.' -ForegroundColor Red
                    }
                    else {
                        Write-Centered 'A mischievous DMT-induced alien shaman challenges you to a game. Win, and you gain 25 extra pockets. Lose, and you lose 5 pockets.'
                        Write-Centered 'Play the game? (Y/N)'
                        # Wait for user to press a valid key
                        $choices = @('Y', 'N')
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        while (-not $choices.Contains($choice)) {
                            $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        }
                        if ($choice -eq 'Y') {
                            $win = Get-Random -Minimum 0 -Maximum 2
                            if ($win -eq 1) {
                                $cosmicGames = @(
                                    'Hopscotch',
                                    'Duck, Duck, Goose',
                                    'Simon Says',
                                    'Musical Chairs',
                                    'Hide and Seek',
                                    'Tic-Tac-Toe'
                                )
                               
                                $cosmicGame = Get-Random -InputObject $cosmicGames
                                Write-Centered ('You outwit the alien shaman in a cosmic game of {0}.' -f $cosmicGame)
                                Start-Sleep -Seconds 2
                                $script:Player.AdjustPocketCount(25)
                                Write-Host
                                Write-Centered 'You gained 25 extra pockets!' -ForegroundColor DarkGreen
                            }
                            else {
                                Write-Centered 'The alien shaman proves to be a cunning opponent.'
                                Start-Sleep -Seconds 2
                                $script:Player.AdjustPocketCount(-5)
                                Write-Host
                                Write-Centered 'You lose 5 pockets in the game. Better luck next time.' -ForegroundColor Red
                            }
                        }
                        else {
                            Write-Centered 'You decide not to play the game, and the alien shaman disappears in a puff of interdimensional smoke. No extra pockets for you.'
                        }
                    }
                }
                4 {
                    Write-Centered 'You find a field of magical pocket flowers. Smelling one might grant you extra pockets.'
                    Write-Centered 'Smell a flower? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        # Generate a random number between 5 and 26, divide it by 5, round up to the nearest whole number, then multiply by 5 to get the number of pockets to gain
                        $pocketsToGain = [Math]::Ceiling((Get-Random -Minimum 5 -Maximum 26) / 5) * 5
                        Write-Centered 'The magical dank kush aroma of the pocket flower works its wonders.'
                        Start-Sleep -Seconds 2
                        Write-Host
                        $script:Player.AdjustPocketCount($pocketsToGain)
                        Write-Centered ('You gained {0} extra pockets!' -f $pocketsToGain) -ForegroundColor DarkGreen
                    }
                    else {
                        Write-Centered 'You decide not to risk it, and the field of pocket flowers fades away.'
                        Start-Sleep -Seconds 2
                        Write-Host
                        Write-Centered 'No extra pockets for you.' -ForegroundColor Red
                    }
                }
            }
        }
    },
    @{
        "Name"        = "Needle Nook"
        "Description" = 'You find yourself in a dimly lit alley, known to locals as the Needle Nook.'
        "Effect"      = {
            Write-Host
            Start-Sleep -Seconds 2
            $choice = Get-Random -Minimum 1 -Maximum 6
    
            switch ($choice) {
                1 {
                    Write-Centered 'A shady dealer offers you a mysterious drug cocktail. Want to try it? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        $randomDrugs = ($script:GameDrugs | Get-Random -Count 4).Name -join ', '
                        # repalce the last ',' with "and"
                        $randomDrugs = $randomDrugs -replace ', ([^,]+)$', ' and $1'
                        $tripOutcome = Get-Random -Minimum 1 -Maximum 11
                        if ($tripOutcome -le 5) {
                            Write-Centered ('The cocktail of {0} hits you hard, and you trip out in a neon-lit dreamscape.' -f $randomDrugs)
                            Tripout
                            Write-Centered 'You lose a day as you navigate the surreal landscapes of your mind.' -ForegroundColor Red
                            AdvanceGameDay -SkipPriceUpdate
                        }
                        else {
                            Write-Centered ('The cocktail of {0} gives you an otherworldly experience.' -f $randomDrugs)
                            Start-Sleep -Seconds 2
                            $cashToAdd = Get-Random -Minimum 20 -Maximum 501
                            Write-Centered ('You find some extra cash in your pocket (after you barf and come down)... ${0}!' -f $cashToAdd) -ForegroundColor DarkGreen
                            $script:Player.Cash += $cashToAdd
                        }
                    }
                    else {
                        Write-Centered 'You decide to pass on the shady dealer''s offer, and they disappear into the shadows. No risk, no reward.'
                    }
                }
                2 {
                    Write-Centered 'A grizzled junkie challenges you to a game of street smarts.'
                    Write-Centered 'Accept the challenge? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        $win = Get-Random -Minimum 0 -Maximum 2
                        $amount = Get-Random -Minimum 10 -Maximum 301
                        if ($win -eq 1) {
                            Write-Centered ('You outwit the junkie in a quick game of street trivia. He rewards you with ${0} cash.' -f $amount) -ForegroundColor DarkGreen
                            $script:Player.Cash += $amount
                        }
                        else {
                            Write-Centered ('The junkie proves to be a street-smart master, and you lose ${0} cash trying to impress him.' -f $amount) -ForegroundColor Red
                            $script:Player.Cash -= $amount
                        }
                    }
                    else {
                        Write-Centered 'You decide not to engage in a street smarts competition, and the junkie nods understandingly, returning to his own world.'
                    }
                }
                3 {
                    Write-Centered 'You come across a hidden stash of drugs. Do you want to take them? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        $randomDrug = $script:GameDrugs | Get-Random
                        $randomDrug.Quantity = Get-Random -Minimum 5 -Maximum 16
                        $mobBeatChance = Get-Random -Minimum 1 -Maximum 101
                        if ($mobBeatChance -le 30) {
                            $mobBosses = @(
                                'Vinny "The Chemist" Marino',
                                'Tony "White Lines" Bianchi',
                                'Frankie "Crystal Clear" Corleone',
                                'Jimmy "Hash Hustler" Capone',
                                'Sal "Opium Queenpin" Santoro',
                                'Mikey "Blow Boss" Moretti',
                                'Louie "Molly Maestro" Lombardi',
                                'Benny "LSD Baron" Barzini',
                                'Nick "Narcotics Napper" Napoli',
                                'Rocco "Coke Cowboy" Colombo',
                                'Maria "The Mixer" Martino',
                                'Angela "Angel Dust" Amato'
                            )                                                     

                            Write-Centered ('You find a stash of {0}, but before you can celebrate {1} jumps you!' -f $randomDrug.Name, (Get-Random -InputObject $mobBosses))
                            Write-Centered ('They beat you up, take back their drugs, and you spend a day recovering in the hospital.') -ForegroundColor Red
                            AdvanceGameDay -SkipPriceUpdate
                        }
                        else {
                            $script:Player.AddDrugs($randomDrug)
                            Write-Centered ('You find a {0}-pocket stash of {1}, adding it to your inventory. The alley holds its secrets.' -f $randomDrug.Quantity, $randomDrug.Name) -ForegroundColor DarkGreen
                        }
                    }
                    else {
                        Write-Centered 'You decide not to take the drugs, leaving the hidden stash undisturbed.'
                    }
                }
                4 {
                    Write-Centered 'A graffiti-covered door catches your eye. Do you want to enter? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        Write-Centered 'You cautiously enter the door and discover a hidden underground club. The beats are pumping, and the atmosphere is wild.'
                        Start-Sleep -Seconds 2
                        $randomCash = [math]::Round((Get-Random -Minimum 30 -Maximum 201) / 10) * 10
                        $script:Player.Cash += $randomCash
                        Write-Centered ('You spend the night dancing and end up finding ${0} cash on the dance floor.' -f $randomCash) -ForegroundColor DarkGreen
                    }
                    else {
                        Write-Centered 'You decide not to enter the mysterious door ''cause you''ve got shit to get done.'
                    }
                }
                5 {
                    Write-Centered 'A disheveled artist offers to sketch your portrait in exchange for some cash. Interested? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        $portraitCost = [math]::Round((Get-Random -Minimum 5 -Maximum 16) / 5) * 5
                        $script:Player.Cash -= $portraitCost
                        Write-Centered ('The artist captures your essence in a gritty portrait. You pay him ${0} for his unique creation.' -f $portraitCost)
    
                        $hashQuantity = Get-Random -Minimum 1 -Maximum 6
                        if ($script:Player.get_FreePocketCount() -ge $hashQuantity) {
                            Write-Host
                            Write-Centered ('As a bonus, the artist hands you {0} pockets of Hash.' -f $hashQuantity) -ForegroundColor DarkGreen
                            $freeHash = [Drug]::new('Hash')
                            $freeHash.Quantity = $hashQuantity
                            $script:Player.AddDrugs($freeHash)
                        }
                        else {
                            Write-Centered 'The artist wanted to give you some Hash, but you don''t have enough free pockets. What a bummer!'
                        }
                    }
                    else {
                        Write-Centered 'You decline the artist''s offer, leaving him to his creative endeavors in the alley.'
                    }
                }
            }
        }
    },
    @{
        "Name"        = "Cocaine Conundrum"
        "Description" = "Oh dear, you find yourself cornered by a self-proclaimed cocaine connoisseur. This enthusiastic individual insists on sharing their 'expertise' and believes they are the absolute BEST at doing cocaine."
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            Write-Centered 'You try to escape, but the self-proclaimed cocaine expert has you trapped in a pointless conversation about their "skills."'
            Start-Sleep -Seconds 3
    
            $awkwardnessLevel = Get-Random -Minimum 1 -Maximum 4
    
            switch ($awkwardnessLevel) {
                1 {
                    Write-Centered 'The cocaine aficionado insists their nose is the most finely tuned instrument for the job.'
                }
                2 {
                    Write-Centered 'They start demonstrating their "perfect" snorting technique, much to your dismay.'
                }
                3 {
                    Write-Centered 'In an attempt to impress you, they share a bizarre list of "achievements" related to their cocaine adventures.'
                }
                default {
                    Write-Centered 'You can''t help but wonder how you ended up in this peculiar conversation about someone being the BEST at doing cocaine.'
                }
            }
    
            Start-Sleep -Seconds 2
            Write-Host
            Write-Host 'How would you like to react?'
            Write-Host '1. Politely nod and pretend to be impressed.'
            Write-Host '2. Burst into laughter and call their bluff.'
            Write-Host '3. Attempt to challenge them with your own made-up cocaine "skills."'
    
            $playerChoice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
    
            Write-Host
            switch ($playerChoice) {
                1 {
                    Write-Centered 'You decide to play along, nodding as if genuinely impressed. The cocaine fiend beams with pride, convinced they''ve found an admirer.'
                }
                2 {
                    Write-Centered 'Unable to contain yourself, you burst into laughter. The cocaine expert looks offended, muttering something about "non-believers" before storming off.'
                }
                3 {
                    Write-Centered 'In a bold move, you attempt to challenge their skills with your own absurd and entirely made-up cocaine "techniques"...'
                    Start-Sleep -Seconds 2
                    $cokeTechniques = @(
                        'You decided to try the latest trend and indulged in a refreshing Cocaine Snow Cone.  That''s some GOOD SLUSHIE!',
                        'In a desperate attempt to boost your energy levels, you resorted to the unconventional Cocaine Coffee Enema, which left you feeling both invigorated and mortified.',
                        'Three words... Cocaine Chocolate Fondue.',
                        'You draw a steaming bubble bath and, with a wicked grin, added a generous dose of Cocaine Infused Bubble Bath, you hop in an scrub until your LIT!',
                        'You shove copious amounts of cocaine where the sun don''t shine, and start dancing around while singing "White Lines" by Grandmaster Flash and Melle Mel.'
                    )

                    $cokeTechnique = Get-Random -InputObject $cokeTechniques
                    Write-Host
                    Write-Centered $cokeTechnique

                    Start-Sleep -Seconds 2
                    Write-Host
                    Write-Centered 'The fiend is left bewildered, questioning your sanity, but now we all know'
                    Write-Centered 'YOU''RE THE BEST AT DOING COCAINE!'
                }
                default {
                    Write-Centered 'You stand there, paralyzed by the absurdity of the situation. The cocaine fiend continues their monologue, oblivious to your internal crisis.'
                }
            }

            Start-Sleep -Seconds 3
            Write-Host
            Write-Centered 'You finally manage to escape the cocaine connoisseur, but not before losing a day to their ramblings.' -ForegroundColor Red
            $cocaine = [Drug]::new('Cocaine')
            $cocaine.Quantity = Get-Random -Minimum 2 -Maximum 6
            
            # If the user has enough free pockets, add the cocaine to their inventory
            if ($script:Player.get_FreePocketCount() -ge $cocaine.Quantity) {
                Write-Host
                Write-Centered 'But at least they gave you some cocaine to make up for it!'
                $script:Player.AddDrugs($cocaine)
                Write-Centered ('You gained {0} pockets of Cocaine.' -f $cocaine.Quantity) -ForegroundColor DarkGreen
            }

            Write-Host
            AdvanceGameDay -SkipPriceUpdate
        }
    }      
)

# Define game guns
$script:GunInfo = @(
    @{
        Name          = "Slingshot"
        Type          = "Projectile weapon"
        StoppingPower = 1
        Price         = 200
        Description   = "A projectile weapon with minimal stopping power, often used for hunting small game or as a recreational activity."
        History       = "Slingshots have been used for thousands of years, with evidence of their use dating back to ancient civilizations such as the Egyptians, Greeks, and Romans."
    },
    @{
        Name          = "Single-shot shotgun"
        Type          = "Shotgun"
        StoppingPower = 2
        Price         = 600
        Description   = "A traditional shotgun with only one barrel, which has limited stopping power compared to a pump or semi-automatic shotgun."
        History       = "The shotgun has its origins in the early 18th century, with the invention of the smoothbore, flintlock firearm. Over time, it has evolved into the modern shotguns we know today."
    },
    @{
        Name          = ".22 caliber rimfire pistol"
        Type          = "Pistol"
        StoppingPower = 3
        Price         = 1000
        Description   = "A small-caliber pistol with limited stopping power, often used for target practice and plinking."
        History       = "The .22 caliber rimfire cartridge was introduced in 1857 by the British firm, Royal Small Arms Factory. It has since become the most popular caliber for firearms worldwide."
    },
    @{
        Name          = "Derringer"
        Type          = "Pistol"
        StoppingPower = 4
        Price         = 1400
        Description   = "A small, pocket-sized pistol with minimal stopping power, typically chambered in .410 gauge or .22 caliber rimfire."
        History       = "The Derringer was invented by Henry Derringer in the early 19th century and gained popularity as a concealable weapon for personal protection."
    },
    @{
        Name          = "Glock 17"
        Type          = "Pistol"
        StoppingPower = 5
        Price         = 1800
        Description   = "A semi-automatic pistol with moderate stopping power."
        History       = "The Glock 17 was introduced in 1982 by Austrian gunmaker Gaston Glock. It has since become one of the most popular handguns worldwide, known for its reliability and ease of use."
    },
    @{
        Name          = "Desert Eagle"
        Type          = "Pistol"
        StoppingPower = 6
        Price         = 2200
        Description   = "A large-frame semi-automatic pistol with significant stopping power."
        History       = "The Desert Eagle was designed by Magnum Research in the late 1970s and early 1980s. It is known for its powerful .50 AE caliber and unique appearance."
    },
    @{
        Name          = "M1911"
        Type          = "Pistol"
        StoppingPower = 7
        Price         = 2600
        Description   = "A semi-automatic pistol with moderate to high stopping power."
        History       = "The M1911, also known as the Model 1911 or Colt 1911, is a single-action, semi-automatic pistol chambered in .45 ACP. It was designed by John Browning and adopted by the United States Armed Forces in 1911."
    },
    @{
        Name          = "Uzi"
        Type          = "Submachine gun"
        StoppingPower = 8
        Price         = 3000
        Description   = "A submachine gun with moderate stopping power."
        History       = "The Uzi was designed by Major Uziel Gal of the Israel Defense Forces in the 1940s and 1950s. It became widely known for its use by Israeli military and police forces, as well as various other militaries and law enforcement agencies around the world."
    },
    @{
        Name          = "MAC-10"
        Type          = "Submachine gun"
        StoppingPower = 9
        Price         = 3400
        Description   = "A submachine gun with moderate stopping power."
        History       = "The MAC-10, or Machine Pistol, was designed by George Kolay in the 1960s as a compact and concealable firearm. It gained notoriety in the 1970s and 1980s for its use in criminal activities, earning it the nickname `"Crime-tech`"."
    },
    @{
        Name          = "Colt Python"
        Type          = "Revolver"
        StoppingPower = 10
        Price         = 3800
        Description   = "A revolver with high stopping power."
        History       = "The Colt Python is a large-frame, double-action revolver produced by the Colt's Manufacturing Company. It was introduced in 1955 and is known for its power, accuracy, and reliability."
    },
    @{
        Name          = "Tommy Gun"
        Type          = "Submachine gun"
        StoppingPower = 10
        Price         = 4200
        Description   = "A classic submachine gun with moderate to high stopping power, known for its high rate of fire and ease of use."
        History       = "The Thompson submachine gun, or Tommy Gun, was designed by John T. Thompson in 1918. It was widely used by law enforcement and military forces in the 1920s and 1930s, and has since become an iconic symbol of the Prohibition era and the gangster culture of that time."
    },
    @{
        Name          = "Barrett M82"
        Type          = "Sniper rifle"
        StoppingPower = 10
        Price         = 4600
        Description   = "A powerful .50 caliber sniper rifle, used by drug lords for its long-range accuracy and destructive power."
        History       = "The Barrett M82, also known as the M82A1, is a .50 caliber anti-materiel rifle developed by the American company Barrett Firearms. It was introduced in the 1980s and has since become one of the most recognized sniper rifles in the world."
    },
    @{
        Name          = "AK-47"
        Type          = "Assault rifle"
        StoppingPower = 10
        Price         = 5000
        Description   = "An assault rifle with high stopping power."
        History       = "The AK-47, also known as the Kalashnikov or Avtomat Kalashnikova, is a gas-operated, 7.62×39mm assault rifle developed in the Soviet Union by Mikhail Kalashnikov. It was introduced in 1947 and has since become one of the most widely used and recognizable firearms in the world."
    },
    @{
        Name          = "AR-15"
        Type          = "Semi-automatic rifle"
        StoppingPower = 10
        Price         = 5000
        Description   = "A semi-automatic rifle with moderate to high stopping power."
        History       = "The AR-15, developed by American firearms designer Eugene Stoner, was first produced in the early 1960s. It was originally designed as a lightweight, adaptable rifle for various purposes, including sport shooting, hunting, and military use. Over time, it has become one of the most popular semi-automatic rifles in the United States."
    },
    @{
        Name          = "FN FAL"
        Type          = "Battle rifle"
        StoppingPower = 10
        Price         = 5000
        Description   = "A battle rifle with high stopping power."
        History       = "The FN FAL, or Fabrique Nationale Fusil Automatique Leger, is a battle rifle developed by the Belgian firearms manufacturer Fabrique Nationale de Herstal. It was introduced in the late 1940s and was widely used by various militaries around the world during the Cold War era."
    }
)
#############################################
#endregion Define Script-Wide Lists and Tables
###############################################

###########################
#region Function Definitions
#############################
# Function that will Exit if console size is not at least 80x25.
function CheckConsoleSize {
    if ($Host.UI.RawUI.WindowSize.Width -lt 120 -or $Host.UI.RawUI.WindowSize.Height -lt 25) {
        Write-Host 'Please resize your console window to at least 120 x 25 and run the script again.' -ForegroundColor Red
        Write-Host ('Current size: {0}x{1}' -f $Host.UI.RawUI.WindowSize.Width, $Host.UI.RawUI.WindowSize.Height) -ForegroundColor Red
        Exit 666
    }
}

# Displays provided text in center of console.
function Write-Centered {
    param (
        [Parameter(Mandatory)]
        [string]$Text,
        [switch]$NoNewline,
        [AllowNull()]
        $BackgroundColor = $null,
        [AllowNull()]
        $ForegroundColor = $null
    )

    # Create hashtable of parameters, so we can splat them to Write-Host.
    $params = @{
        NoNewline       = $NoNewline
        BackgroundColor = $BackgroundColor
        ForegroundColor = $ForegroundColor
    }

    # Create a new hashtable excluding entries with null values.
    $filteredParams = @{}
    foreach ($key in $params.Keys) {
        $value = $params[$key]
        if ($null -ne $value) {
            $filteredParams[$key] = $value
        }
    }

    # Get console width
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width

    # If the text is longer than the console width -2, split the Text into an array of multiple lines...
    # Create a new list to store the lines of text
    $textList = New-Object System.Collections.Generic.List[string]

    # Check if the length of the text is greater than the console width minus 2
    if ($Text.Length -gt ($consoleWidth - 2)) {
        # Store the length of the text and the maximum line length
        $textLength = $Text.Length
        $lineLength = $consoleWidth - 2

        # Loop while there is still text left
        while ($textLength -gt 0) {
            # Calculate the end index for the substring
            $endIndex = [math]::Min($lineLength, $textLength)
            # Extract the substring from the text
            $stringToAdd = $Text.Substring(0, $endIndex)

            # Check if the string contains a space and if the text length is not equal to the end index
            $shouldTruncate = $stringToAdd.Contains(' ') -and ($textLength -ne $endIndex)
            if ($shouldTruncate) {
                # Find the last space in the string
                $lastSpace = $stringToAdd.LastIndexOf(' ')
                # Truncate the string at the last space
                $stringToAdd = $stringToAdd.Substring(0, $lastSpace + 1)
            }

            # Add the string to the list and trim it
            $textList.Add($stringToAdd.Trim())
            # Remove the string from the text and trim it
            $Text = $Text.Substring($stringToAdd.Length).Trim()
            # Update the text length
            $textLength = $Text.Length
        }
    }
    else {
        # If the text is not longer than the console width minus 2, add it to the list as is
        $textList.Add($Text)
    }

    # Iterate through each line in the array
    foreach ($line in $textList) {
        # Calculate padding to center text
        $padding = [math]::Max(0, [math]::Floor((($consoleWidth - $line.Length) / 2)))

        # Calculate right padding
        $rightPadding = $consoleWidth - $line.Length - $padding

        # If right padding is negative, set it to zero
        if ($rightPadding -lt 0) {
            $rightPadding = 0
        }

        # Write text to console with padding, using the filtered parameters.
        Write-Host ((' ' * $padding) + $line + (' ' * $rightPadding)) @filteredParams
    }
}

# Function to write large block letters to the console, based on provided text.
function Write-BlockLetters {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [ValidateSet("Left", "Center", "Right")]
        [string]$Align = "Left",
        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor,
        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [int]$VerticalPadding = 0
    )
    
    # Define the mapping of characters to their block letter representations
    $blockLetters = @{
        'A'  = @(
            "  #  ",
            " # # ",
            "#####",
            "#   #",
            "#   #"
        )
        'B'  = @(
            "#### ",
            "#   #",
            "#### ",
            "#   #",
            "#### "
        )
        'C'  = @(
            " ### ",
            "#   #",
            "#    ",
            "#   #",
            " ### "
        )
        'D'  = @(
            "#### ",
            "#   #",
            "#   #",
            "#   #",
            "#### "
        )
        'E'  = @(
            "#####",
            "#    ",
            "#### ",
            "#    ",
            "#####"
        )
        'F'  = @(
            "#####",
            "#    ",
            "#### ",
            "#    ",
            "#    "
        )
        'G'  = @(
            " ### ",
            "#    ",
            "#  ##",
            "#   #",
            " ### "
        )
        'H'  = @(
            "#   #",
            "#   #",
            "#####",
            "#   #",
            "#   #"
        )
        'I'  = @(
            "#####",
            "  #  ",
            "  #  ",
            "  #  ",
            "#####"
        )
        'J'  = @(
            "#####",
            "   # ",
            "   # ",
            "#  # ",
            " ##  "
        )
        'K'  = @(
            "#   #",
            "#  # ",
            "###  ",
            "#  # ",
            "#   #"
        )
        'L'  = @(
            "#    ",
            "#    ",
            "#    ",
            "#    ",
            "#####"
        )
        'M'  = @(
            "#   #",
            "## ##",
            "# # #",
            "#   #",
            "#   #"
        )
        'N'  = @(
            "#   #",
            "##  #",
            "# # #",
            "#  ##",
            "#   #"
        )
        'O'  = @(
            " ### ",
            "#   #",
            "#   #",
            "#   #",
            " ### "
        )
        'P'  = @(
            "#### ",
            "#   #",
            "#### ",
            "#    ",
            "#    "
        )
        'Q'  = @(
            " ### ",
            "#   #",
            "# # #",
            "#  # ",
            " ## #"
        )
        'R'  = @(
            "#### ",
            "#   #",
            "#### ",
            "# #  ",
            "#  ##"
        )
        'S'  = @(
            " ####",
            "#    ",
            " ### ",
            "    #",
            "#### "
        )
        'T'  = @(
            "#####",
            "  #  ",
            "  #  ",
            "  #  ",
            "  #  "
        )
        'U'  = @(
            "#   #",
            "#   #",
            "#   #",
            "#   #",
            " ### "
        )
        'V'  = @(
            "#   #",
            "#   #",
            "#   #",
            " # # ",
            "  #  "
        )
        'W'  = @(
            "#   #",
            "#   #",
            "# # #",
            "## ##",
            "#   #"
        )
        'X'  = @(
            "#   #",
            " # # ",
            "  #  ",
            " # # ",
            "#   #"
        )
        'Y'  = @(
            "#   #",
            " # # ",
            "  #  ",
            "  #  ",
            "  #  "
        )
        'Z'  = @(
            "#####",
            "   # ",
            "  #  ",
            " #   ",
            "#####"
        )
        '0'  = @(
            " ### ",
            "#   #",
            "# # #",
            "#   #",
            " ### "
        )
        '1'  = @(
            " # ",
            "## ",
            " # ",
            " # ",
            "###"
        )
        '2'  = @(
            " ### ",
            "#   #",
            "  ## ",
            " #   ",
            "#####"
        )
        '3'  = @(
            " ### ",
            "#   #",
            "  ## ",
            "#   #",
            " ### "
        )
        '4'  = @(
            "#  # ",
            "#  # ",
            "#####",
            "   # ",
            "   # "
        )
        '5'  = @(
            "#####",
            "#    ",
            "#### ",
            "    #",
            "#### "
        )
        '6'  = @(
            " ### ",
            "#    ",
            "#### ",
            "#   #",
            " ### "
        )
        '7'  = @(
            "#####",
            "   # ",
            "  #  ",
            " #   ",
            "#    "
        )
        '8'  = @(
            " ### ",
            "#   #",
            " ### ",
            "#   #",
            " ### "
        )
        '9'  = @(
            " ### ",
            "#   #",
            " ####",
            "    #",
            " ### "
        )
        '.'  = @(
            "   ",
            "   ",
            "   ",
            "   ",
            " # "
        )
        '?'  = @(
            " ### ",
            "#   #",
            "   # ",
            "     ",
            "  #  "
        )
        '!'  = @(
            "##",
            "##",
            "##",
            "  ",
            "##"
        )
        '$'  = @(
            " ### ",
            "# #  ",
            " ### ",
            "  # #",
            " ### "
        )
        '-'  = @(
            "    ",
            "    ",
            "####",
            "    ",
            "    "
        )
        '+'  = @(
            "   ",
            " # ",
            "###",
            " # ",
            "   "
        )
        '='  = @(
            "    ",
            "####",
            "    ",
            "####",
            "    "
        )
        '_'  = @(
            "    ",
            "    ",
            "    ",
            "    ",
            "####"
        )
        ' '  = @(
            "  ",
            "  ",
            "  ",
            "  ",
            "  "
        )
        '<'  = @(
            "  #",
            " # ",
            "#  ",
            " # ",
            "  #"
        )
        '>'  = @(
            "#  ",
            " # ",
            "  #",
            " # ",
            "#  "
        )
        '@'  = @(
            " ### ",
            "#   #",
            "# ###",
            "# # #",
            "# ### "
        )
        '#'  = @(
            " # # ",
            "#####",
            " # # ",
            "#####",
            " # # "
        )
        '%'  = @(
            "#   #",
            "   # ",
            "  #  ",
            " #   ",
            "#   #"
        )
        '^'  = @(
            " # ",
            "# #",
            "   ",
            "   ",
            "   "
        )
        '&'  = @(
            " ##  ",
            "#  # ",
            " ##  ",
            "#  # ",
            " ## #"
        )
        '*'  = @(
            "  #  ",
            "# # #",
            " ### ",
            "# # #",
            "  #  "
        )
        '('  = @(
            " #",
            "# ",
            "# ",
            "# ",
            " #"
        )
        ')'  = @(
            "# ",
            " #",
            " #",
            " #",
            "# "
        )
        ':'  = @(
            "   ",
            " # ",
            "   ",
            " # ",
            "   "
        )
        ';'  = @(
            "   ",
            " # ",
            "   ",
            " # ",
            "#  "
        )
        ','  = @(
            "   ",
            "   ",
            "   ",
            " # ",
            "#  "
        )
        '''' = @(
            " #",
            "# ",
            "  ",
            "  ",
            "  "
        )
        '"'  = @(
            "# #",
            "# #",
            "   ",
            "   ",
            "   "
        )
    }
    
    # Convert the input text to block letters and create an array of lines containing the block letters
    $TextUpper = $Text.ToUpper()
    $lines = for ($i = 0; $i -lt 5; $i++) {
        $line = foreach ($char in [char[]]$TextUpper) {
            $char = $char.ToString()
            if ($blockLetters.ContainsKey($char)) {
                $blockLetters[$char][$i] + " "
            }
            else {
                $blockLetters['?'][$i] + " "
            }
        }
        # Join the line array into a string and trim the last character
        $joinedLine = $line -join ""
        $joinedLine.Substring(0, $joinedLine.Length - 1)
    }
    
    # Get width of the longest line (as integer)
    $longestLine = ($lines | Measure-Object -Property Length -Maximum).Maximum
    
    # Add blank vertical padding lines to the top and bottom $lines array that are as wide as the longest line.
    for ($i = 0; $i -lt $VerticalPadding; $i++) {
        $lines = @(" " * $longestLine) + $lines + @(" " * $longestLine)
    }
    
    # Get the console width
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    
    # Calculate the padding based on the chosen alignment and console width
    switch ($Align) {
        "Left" {
            $leftPadding = 0
        }
        "Center" {
            $leftPadding = [Math]::Floor(($consoleWidth - $longestLine) / 2)
            if ($leftPadding -lt 0) {
                $leftPadding = 0
            }
            $rightPadding = $consoleWidth - $longestLine - $leftPadding
            if ($rightPadding -lt 0) {
                $rightPadding = 0
            }
        }
        "Right" {
            $leftPadding = $consoleWidth - $longestLine
        }
    }
    
    if ($consoleWidth -lt ($longestLine + 2)) {
        # If the console width is less than the longest line plus 2, return false
        return $false
    }
    else {
        # Write the text to the console as block characters, line by line.
        $lines | ForEach-Object {
            $line = $_
    
            if ($Align -eq "Center") {
                # Right padding is added so we can fill it with spaces/background colour when using centered alignment.
                $line = (" " * $leftPadding) + $line + (" " * $rightPadding)
            }
            else {
                $line = (" " * $leftPadding) + $line
            }
    
            # If $line is empty (i.e. all spaces), write the line as a whole
            if ($line.Trim().Length -eq 0) {
                Write-Host $line -NoNewLine -BackgroundColor $BackgroundColor
            }
            else {
                # Write the line to the console, character by character
                for ($i = 0; $i -lt $line.Length; $i++) {
                    $char = $line[$i]
    
                    # If the character is a space, write a space with the background color, otherwise write a space with the foreground color (to represent a lit pixel in the character).
                    if ($char -eq " ") {
                        Write-Host " " -NoNewline -BackgroundColor $BackgroundColor
                    }
                    else {
                        Write-Host " " -NoNewline -BackgroundColor $ForegroundColor 
                    }        
                }
            }
    
            # Add New Line to end.
            Write-Host
        }
    }
}

# Initialize game state
function InitGame {
    # Game settings
    $startingCash = 2000
    $startingPockets = 100
    $cityCount = 8
    $gameDrugCount = 10
    $cityDrugCount = 6
    $script:GameDays = 30
    $script:GameOver = $false
    $script:RandomEventChance_Start = 10 # Percentage
    $script:RandomEventChance_Current = $script:RandomEventChance_Start

    # Create and populate the drugs available for this game session.
    [Drug[]]$script:GameDrugs = InitGameDrugs -DrugCount $gameDrugCount

    # Create and populate the cities available for this game session.
    [City[]]$script:GameCities = InitGameCities -CityCount $cityCount -MaxDrugCount $cityDrugCount

    # Create player object, and populate with game-starting values.
    [Player]$script:Player = [Player]::new()
    $script:Player.Cash = $startingCash
    $script:Player.City = $script:GameCities | Get-Random
    $script:Player.set_PocketCount($startingPockets)

    # Fill starting City with random drugs.
    $script:Player.City.Drugs = $script:GameDrugs | Get-Random -Count $script:Player.City.MaxDrugCount
}

# Populates an array of City objects, using randomly chosen, unique names from the CityNames array.
function InitGameCities {
    param (
        [int]$CityCount = 8,
        [int]$MaxDrugCount = 6
    )

    $cities = @()

    $gameCityNames = $script:CityNames | Get-Random -Count $CityCount | Sort-Object -Unique
    $gameCityNames | ForEach-Object {
        $city = [City]::new()
        $city.Name = $_
        $city.Drugs = @()
        $city.MaxDrugCount = $MaxDrugCount
        $city.HomeDrugNames = @()
        $city.HomeDrugPriceMultiplier = .80

        # Assign 1 or 2 random 'Home Drugs' to each city. These will stay the same for the entire game.
        # Home Drugs are drugs that are always sold at a discount (if in stock).
        $homeDrugCount = Get-Random -Minimum 1 -Maximum 3
        $script:GameDrugs | Get-Random -Count $homeDrugCount | ForEach-Object {
            $city.HomeDrugNames += $_.Name
        }

        $cities += $city
    }

    return $cities
}

# Populates an array of Drug objects, using randomly chosen, unique names from the DrugNames array.
function InitGameDrugs {
    param (
        [int]$DrugCount = 10
    )

    $drugs = @()

    $drugCodes = $script:DrugCodes.Keys | Get-Random -Count $DrugCount | Sort-Object -Unique
    $drugCodes | ForEach-Object {
        $drug = [Drug]::new($script:DrugsInfo[$_]['Name'])
        $drug.Code = $_
        $drug.PriceRange = $script:DrugsInfo[$_]['PriceRange']
        $drug.PriceMultiplier = 1.0
        $drug.Quantity = 0

        $drugs += $drug
    }

    return $drugs
}

# Function to display list of provided cities in two alphabetized columns to the console.
function DisplayCities {
    param (
        [Parameter(Mandatory)]
        [City[]]$Cities
    )

    $sortedCities = $Cities.Name | Sort-Object
    $halfCount = [math]::Ceiling($sortedCities.Count / 2)

    $boxWidth = 76
    $leftColumnWidth = 35
    $rightColumnWidth = 35
    $gutterWidth = 1

    # Top border
    Write-Centered ('┌' + ('─' * ($boxWidth - 1)) + '┐')

    for ($i = 0; $i -lt $halfCount; $i++) {
        $leftCity = "$($i + 1). $($sortedCities[$i])"
        $rightCity = "$($i + $halfCount + 1). $($sortedCities[$i + $halfCount])"

        $leftCity = $leftCity.PadRight($leftColumnWidth)
        $rightCity = $rightCity.PadRight($rightColumnWidth)

        # Left gutter
        Write-Centered ('│' + (' ' * $gutterWidth) + $leftCity + (' ' * $gutterWidth) + '│' + (' ' * $gutterWidth) + $rightCity + (' ' * $gutterWidth) + '│')

        # Middle border
        if ($i -eq $halfCount - 1) {
            Write-Centered ('└' + ('─' * ($leftColumnWidth + $gutterWidth * 2)) + ('┴' + ('─' * ($rightColumnWidth + $gutterWidth * 2))) + '┘')
        }
        else {
            Write-Centered ('│' + (' ' * $gutterWidth) + ('─' * $leftColumnWidth) + (' ' * $gutterWidth) + '│' + (' ' * $gutterWidth) + ('─' * $rightColumnWidth) + (' ' * $gutterWidth) + '│')
        }
    }
}

# This function generates a string of drug names, separated by commas, based on the indices provided in the 'HomeDrugNames' array.
function GetHomeDrugString {
    param (
        [Parameter(Mandatory)]
        [string[]]$HomeDrugNames
    )

    $homeDrugString = ''
    for ($i = 0; $i -lt $HomeDrugNames.Count; $i++) {
        $homeDrugString += $HomeDrugNames[$i]
        if ($i -lt ($HomeDrugNames.Count - 1)) {
            $homeDrugString += ', '
        }
    }
    return $homeDrugString
}

# This function displays a menu header with the player's current cash, city, and home drug information in a formatted string.
function ShowMenuHeader {
    $homeDrugString = GetHomeDrugString -HomeDrugNames $script:Player.City.HomeDrugNames

    Write-Host ('·' + ('═' * ($Host.UI.RawUI.WindowSize.Width - 2)) + '·') -ForegroundColor DarkGray
    Write-Centered ('Drug Wars :: Day {3} :: {1} ({2})' -f $script:Player.Cash, $script:Player.City.Name, $homeDrugString, $script:Player.GameDay)
    Write-centered ('Cash: ${0} :: Free Pockets: {1}/{2}' -f $script:Player.Cash, $script:Player.get_FreePocketCount(), $script:Player.Pockets)
    Write-Host ('·' + ('═' * ($Host.UI.RawUI.WindowSize.Width - 2)) + '·') -ForegroundColor DarkGray
}

# This function displays a psychedelic animation to the console.
function Tripout {
    param (
        [int]$LoopTime = 8
    )

    # Loop for X seconds (default 8)
    $startTime = Get-Date
    while ((Get-Date) -lt ($startTime.AddSeconds($LoopTime))) {
        # Get the current cursor position and buffer size
        $cursor = $Host.UI.RawUI.CursorPosition
        $buffer = $Host.UI.RawUI.BufferSize

        # Create a rectangle that covers the screen buffer from the top left corner to the cursor position
        $rect = New-Object System.Management.Automation.Host.Rectangle 0, 0, ($buffer.Width - 1), $cursor.Y

        # Get the buffer contents as an array of BufferCell objects
        $cells = $Host.UI.RawUI.GetBufferContents($rect)

        # Set the cursor position to the top left corner
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0, 0

        # Loop through the array and write each character with its original background color
        foreach ($cell in $cells) {
            # Convert the character to a string
            $charString = [string]$cell.Character

            # Randomly choose to convert the character to uppercase or lowercase
            $char = if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) {
                $charString.ToUpper()
            }
            else {
                $charString.ToLower()
            }

            Write-Host $char -NoNewline -ForegroundColor $(Get-Random -Minimum 1 -Maximum 16) -BackgroundColor $cell.BackgroundColor
        }

        Start-Sleep -Milliseconds $(Get-Random -Minimum 1 -Maximum 180)
    }
}

# This function displays the "Drug-O-Peida".
function ShowDrugopedia {
    Clear-Host
    ShowMenuHeader
    Write-Host
    Write-Centered '--------------'
    Write-Centered 'Drug-o-pedia'
    Write-Centered '--------------'
    Write-Host
    Write-Centered 'Information about the drugs currently active in this game session.'
    Write-Host
    $script:GameDrugs | ForEach-Object {
        Write-Host ('· {0} ({1})' -f $_.Name, $_.Code)
        Write-Host ('· Price Range: ${0}-${1}' -f $_.PriceRange[0], $_.PriceRange[1])
        Write-Host ('· History: {0}' -f $script:DrugsInfo[$_.Code].History)        
        Write-Host ('· Effects: {0}' -f $script:DrugsInfo[$_.Code].Effects)
        $streetNames = $script:DrugsInfo[$_.Code].StreetNames -join ', '
        Write-Host ('· Other Street Names: {0}' -f $streetNames)
        Write-Host
    }
    PressEnterPrompt
}

# This function displays the main menu of the game.
function ShowMainMenu {
    Clear-Host
    ShowMenuHeader

    Write-Host

    # Define the column width
    $columnWidth = 38

    # Print the headers
    Write-Centered ("{0,-$columnWidth}{1,-$columnWidth}" -f "Your drugs:", "Your clothes:")

    # Get the maximum count between the two collections
    $maxCount = [Math]::Max($script:Player.Drugs.Count, $script:Player.Clothing.Count)

    # Loop that many times
    for ($i = 0; $i -lt $maxCount; $i++) {
        # Get the drug and clothing at the current index, or null if the index is out of range
        $dispDrug = if ($i -lt $script:Player.Drugs.Count) { 
            '· {0} {1}' -f $script:Player.Drugs[$i].Quantity, $script:Player.Drugs[$i].Name 
        }
        elseif ($i -eq 0) {
            '· You have 0 marijuanas.' 
        }

        $dispClothing = if ($i -lt $script:Player.Clothing.Count) { 
            '· {0}' -f $script:Player.Clothing[$i] 
        }
        elseif ($i -eq 0) {
            '· You are naked.' 
        }

        Write-Centered ("{0,-$columnWidth}{1,-$columnWidth}" -f $dispDrug, $dispClothing)
    }

    Write-Host
    Write-Host '[B]uy drugs'
    Write-Host '[S]ell drugs'
    Write-Host '[J]et to another city'
    Write-Host
    Write-Host '[Q]uit'
    Write-Host '[?]Help'
    Write-Host
    Write-Host 'What now, boss? ' -NoNewline

    # Wait for user to press a valid key
    $choices = @('B', 'S', 'J', 'Q', '?', 'D', '!')
    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
    while (-not $choices.Contains($choice)) {
        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
    }

    # Return the Character of the key that was pressed (upper case)
    return $choice
}

# Function to display drugs available in a city in a two column display
function ShowCityDrugs {
    param (
        [Parameter(Mandatory)]
        [City]$City
    )
        
    $drugCount = $city.Drugs.Count
    $halfCount = [math]::Ceiling($drugCount / 2)
    $boxWidth = 76
    $leftColumnWidth = 35
    $rightColumnWidth = 35
    $gutterWidth = 1

    # Top border
    Write-Centered ('┌' + ('─' * ($boxWidth - 1)) + '┐')

    for ($i = 0; $i -lt $halfCount; $i++) {
        $leftDrug = ('{0}. {1} - ${2}' -f ($i + 1), $city.Drugs[$i].Name, $city.Drugs[$i].get_Price())
        $rightDrug = ('{0}. {1} - ${2}' -f ($i + $halfCount + 1), $city.Drugs[$i + $halfCount].Name, $city.Drugs[$i + $halfCount].get_Price())

        $leftDrug = $leftDrug.PadRight($leftColumnWidth)
        $rightDrug = $rightDrug.PadRight($rightColumnWidth)

        # Left gutter
        Write-Centered ('│' + (' ' * $gutterWidth) + $leftDrug + (' ' * $gutterWidth) + '│' + (' ' * $gutterWidth) + $rightDrug + (' ' * $gutterWidth) + '│')

        # Middle border
        if ($i -eq $halfCount - 1) {
            Write-Centered ('└' + ('─' * ($leftColumnWidth + $gutterWidth * 2)) + ('┴' + ('─' * ($rightColumnWidth + $gutterWidth * 2))) + '┘')
        }
        else {
            Write-Centered ('│' + (' ' * $gutterWidth) + ('─' * $leftColumnWidth) + (' ' * $gutterWidth) + '│' + (' ' * $gutterWidth) + ('─' * $rightColumnWidth) + (' ' * $gutterWidth) + '│')
        }
    }
}

# This function displays the drug buying menu.
function ShowBuyDrugsMenu {
    Clear-Host
    ShowMenuHeader
    Write-Host    
    Write-Centered "Buy Drugs"
    Write-Host
    ShowCityDrugs $script:Player.City
    Write-Host
    $drugCount = $script:Player.City.Drugs.Count
    Write-Centered "Enter the number of the drug you want to buy (1-$drugCount, or 'Q' to return to the main menu) " -NoNewline
    $drugNumber = $null
    while (-not $drugNumber) {
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString()
        switch ($key) {
            { $_ -in '1'.."$drugCount" } { $drugNumber = [int]$key; break }
            { $_ -in 'q', 'Q' } { return }
        }
    }

    Write-Host
    # Create clone of drug object for transaction.
    $cityDrug = $script:Player.City.Drugs[$drugNumber - 1]
    $drugToBuy = [Drug]::new($cityDrug.Name)
    $drugToBuy.BasePrice = $cityDrug.BasePrice
    $drugToBuy.PriceMultiplier = $cityDrug.PriceMultiplier

    $maxQuantity = [math]::Floor($script:Player.Cash / $drugToBuy.get_Price())

    # Ask how many they want to buy.
    $quantity = Read-Host "Enter the quantity you want to buy (max $maxQuantity)"
    $quantityInt = 0
    if (-not [int]::TryParse($quantity, [ref]$quantityInt) -or $quantityInt -lt 1) {
        Write-Centered "Invalid quantity."
        PressEnterPrompt
        return
    }

    # Buy the drugs.
    $drugToBuy.Quantity = $quantityInt
    $script:Player.BuyDrugs($drugToBuy)
    
    PressEnterPrompt
}

# This function displays the drug selling menu.
function ShowSellDrugsMenu {
    Clear-Host
    ShowMenuHeader
    Write-Host    
    Write-Centered "Sell Drugs"
    Write-Host
    ShowCityDrugs $script:Player.City
    Write-Host
    $drugCount = $script:Player.City.Drugs.Count

    # Ask which drug they want to sell.
    Write-Centered "Enter the number of the drug you want to sell (1-$drugCount, or 'Q' to return to the main menu) " -NoNewline
    $drugNumber = $null
    while (-not $drugNumber) {
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString()
        switch ($key) {
            { $_ -in '1'.."$drugCount" } { $drugNumber = [int]$key; break }
            { $_ -in 'q', 'Q' } { return }
        }
    }

    Write-Host
    $nameOfDrugToSell = $script:Player.City.Drugs[$drugNumber - 1].Name
    $drugToSell = $script:Player.Drugs | Where-Object { $_.Name -eq $nameOfDrugToSell }


    if (!$drugToSell) {
        Write-Centered ('You don''t have any {0} to sell!' -f $nameOfDrugToSell)
        PressEnterPrompt
        return
    }

    $maxQuantity = $drugToSell.Quantity

    # Ask how many they want to sell.
    $quantity = Read-Host ('Enter the quantity you want to sell (max {0})' -f $maxQuantity)
    $quantityInt = 0
    if (-not [int]::TryParse($quantity, [ref]$quantityInt) -or $quantityInt -lt 1) {
        Write-Centered "Invalid quantity."
        PressEnterPrompt
        return
    }

    # Sell the drugs.
    $script:Player.SellDrugs($drugToSell, $quantityInt)

    PressEnterPrompt
}

# This function displays a list of cities to the console, and prompts the user to select a city to travel to.
function Jet {
    Clear-Host
    ShowMenuHeader
    Write-Host
    Write-Centered "Jet to Another City"
    Write-Host
    DisplayCities -Cities $script:GameCities
    Write-Host
    $cityCount = $script:GameCities.Count

    $ticketPrice = 100
    # If the player cna't pay the ticket price, tell them and then exit the function.
    if ($script:Player.Cash -lt $ticketPrice) {
        Write-Centered ('You don''t have enough cash to buy a ticket, Chum...p!') -ForegroundColor Red
        Start-Sleep 3
        PressEnterPrompt
        return
    }

    $newCity = $null
    Write-Centered "Enter the city you want to jet to (1-$cityCount, or 'Q' to return to the main menu) " -NoNewline
    while (-not $newCity) {
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString()
        switch ($key) {
            { $_ -in '1'.."$cityCount" } { $newCity = [int]$key; break }
            { $_ -in 'q', 'Q' } { return }
        }
    }
    Write-Host

    # Alphabetize the cities by name, then assign the player's city to the selected city.
    [City[]]$alphabetizedCities = $script:GameCities | Sort-Object -Property Name
    $destinationCity = $alphabetizedCities[$newCity - 1]

    # If the new city is different from the current city, then travel to the new city.
    if ($script:Player.City -ne $destinationCity) {
        Write-Host
        Write-Centered ('You hit the airport and catch a flight to {0}.' -f $destinationCity.Name)
        Start-Sleep -Milliseconds 500
        Write-Centered ('The ticket costs you ${0}, and the trip takes a day.' -f $ticketPrice) -ForegroundColor Yellow

        # Subtract ticket price from player's cash.
        $script:Player.Cash -= $ticketPrice

        Start-Sleep 3
        Write-Host

        # Travel takes a day, change clothes
        AdvanceGameDay -ChangeOutfit

        # Set player's new location.
        $script:Player.City = $destinationCity

        # Fill landing City with random drugs.
        $script:Player.City.Drugs = $script:GameDrugs | Get-Random -Count $script:Player.City.MaxDrugCount

        $arrivalMessages = @(
            'You arrive in {0} and immidiately hit the streets.',
            'Welcome to beautiful {0}!',
            'You arrive in {0} and get to hustlin''.',
            'As you arrive in {0}, you can''t help but notice the smell of {1} in the air.',
            'Welcome to {0}. What a shit-hole.'
        )

        $arrivalMessage = Get-Random -InputObject $arrivalMessages
        Write-Host
        Write-Centered ($arrivalMessage -f $destinationCity.Name, $destinationCity.HomeDrugNames[0]) -ForegroundColor Green
    }
    else {
        Write-Host
        Write-Centered ('Lay off your stash man!  You''re already in {0}!' -f $script:Player.City.Name) -ForegroundColor Yellow
    }

    Start-Sleep 2
    Write-Host
    PressEnterPrompt
}

# This function handles a random event.
function StartRandomEvent {
    $randomEvent = $script:RandomEvents | Get-Random

    Clear-Host
    ShowMenuHeader
    Write-Host
    $eventName = ('{0}!' -f $randomEvent.Name)
    if ((Write-BlockLetters $eventName -Align Center) -eq $false) {
        Write-Centered $eventName
    }
    Write-Host
    Write-Host
    Write-Centered $randomEvent.Description
    & $randomEvent.Effect
    Write-Host
    PressEnterPrompt
}

# This function displays a prompt to the user to press Enter to continue.
function PressEnterPrompt {
    Write-Centered 'Press Enter to continue' -NoNewline
    $choice = $null
    while ($choice.VirtualKeyCode -ne 13) {
        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    
}

# This function is called when the player chooses to quit the game.
function QuitGame {
    # Check if they're sure they want to quit.
    Write-Host
    Write-Centered 'Are you sure you want to quit? (Y/N)' -NoNewline
    # Wait for user to press a valid key
    $choices = @('Y', 'N')
    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
    while (-not $choices.Contains($choice)) {
        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
    }

    if ($choice -eq 'Y') {
        EndGame
    }
}

# This function is called to end the game.
function EndGame {
    Clear-Host
    Write-Host
    $days = $script:Player.GameDay
    $daysLabel = if ($days -eq 1) { 'day' } else { 'days' }
    Write-Centered ('You survived {0} {1}, and ended up with ${2} in cash.' -f $days, $daysLabel, $script:Player.Cash)
    if ($script:Player.Drugs.Count -gt 0) {
        Write-Host
        Write-Centered 'Drugs left over:'
        $script:Player.Drugs | ForEach-Object {
            Write-Centered ('· {0} {1}' -f $_.Quantity, $_.Name)
        }
    }
    Write-Host
    if ((Write-BlockLetters 'Thanks for playing!' -Align Center -BackgroundColor Blue -VerticalPadding 1) -eq $false) {
        Write-Centered 'Thanks for playing!' -BackgroundColor Blue
    }
    
    if (IsHighScore -Score $script:Player.Cash) {
        Write-Host
        Write-Centered 'You got a high score!' -ForegroundColor Green
        Write-Host
        Write-Centered 'Enter your initials to save it to the high score list:'
        Write-Host

        # Figure out leftpadding for input of initials
        $leftPadding = [Math]::Floor(($Host.UI.RawUI.WindowSize.Width - 3) / 2)
        Write-Host (' ' * $leftPadding) -NoNewline

        $initials = ""
        while ($true) {
            $key = [System.Console]::ReadKey($true)
            if ($key.Key -eq "Enter") {
                break
            }
            elseif ($key.Key -eq "Backspace") {
                if ($initials.Length -gt 0) {
                    $initials = $initials.Substring(0, $initials.Length - 1)
                    [System.Console]::Write("`b `b") # erase the last character
                }
            }
            elseif ($initials.Length -lt 3) {
                $upperCasedChar = $key.KeyChar.ToString().ToUpper()
                $initials += $upperCasedChar
                [System.Console]::Write($upperCasedChar)
            }
        }
        Write-Host

        # Convert the initials to uppercase, and save them to the player object.
        $script:Player.Initials = $initials.ToUpper()
        
        # Add the high score to the high score list.
        AddHighScore -Initials $script:Player.Initials -Score $script:Player.Cash
    }

    # Display high scores center justified on screen, with a header
    Write-Host
    Write-Centered 'Highest Dealers'
    Write-Centered '---------------'
    Write-Host
    $highScores = GetHighScores
    $maxScoreLength = ($highScores | Measure-Object -Property Score -Maximum).Maximum.ToString().Length

    $highScores | ForEach-Object {
        $score = $_.Score.ToString().PadRight($maxScoreLength)
        if ($_.Initials -eq $script:Player.Initials -and $_.Score -eq $script:Player.Cash) {
            Write-Centered ('-> {0} - ${1} <-' -f $_.Initials, $score) -ForegroundColor Green
        }
        elseif ($_.Initials -eq $highScores[0].Initials -and $_.Score -eq $highScores[0].Score) {
            Write-Centered ('{0} - ${1}' -f $_.Initials, $score) -ForegroundColor Yellow
        }
        elseif ($_.Initials -eq $highScores[1].Initials -and $_.Score -eq $highScores[1].Score) {
            Write-Centered ('{0} - ${1}' -f $_.Initials, $score) -ForegroundColor Gray
        }
        elseif ($_.Initials -eq $highScores[2].Initials -and $_.Score -eq $highScores[2].Score) {
            Write-Centered ('{0} - ${1}' -f $_.Initials, $score) -ForegroundColor DarkYellow
        }
        else {
            Write-Centered ('{0} - ${1}' -f $_.Initials, $score) -ForegroundColor DarkGray
        }
    }

    $script:GameOver = $true
    
    Write-Host
    Write-Centered 'Would you like to play again? (Y/N)' -NoNewline
    # Wait for user to press a valid key
    $choices = @('Y', 'N')
    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
    while (-not $choices.Contains($choice)) {
        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
    }

    if ($choice -eq 'N') {
        $script:Playing = $false
    }
}

# This function displays the help screen.
function ShowHelp {
    Clear-Host
    ShowMenuHeader
    Write-Host
    Write-Centered "------"
    Write-Centered "Help"
    Write-Centered "------"
    Write-Host
    Write-Centered "Drug Wars is a text-based game where you buy and sell drugs in various cities around the world."
    Write-Centered "The goal is to make as much cash money as possible in $script:GameDays days."
    Write-Host
    Write-Host "Main Menu"
    Write-Host "---------"
    Write-Host "[B]uy drugs"
    Write-Host "[S]ell drugs"
    Write-Host "[J]et to another city"
    Write-Host "[Q]uit"
    Write-Host
    Write-Host "Buy Drugs"
    Write-Host "---------"
    Write-Host "This displays the current prices of all drugs in the city you are in."
    Write-Host "Enter the name of the drug you want to buy, and the quantity you want to buy."
    Write-Host "You can only buy as much as you can afford, and as much as you have room for in your pockets."
    Write-Host
    Write-Host "Sell Drugs"
    Write-Host "----------"
    Write-Host "This displays the current prices of all drugs in the city you are in."
    Write-Host "Enter the name of the drug you want to sell, and the quantity you want to sell."
    Write-Host "You can only sell as much as you have in your inventory."
    Write-Host
    Write-Host "Jet to Another City"
    Write-Host "-------------------"
    Write-Host "This displays a list of cities you can travel to."
    Write-Host "Enter the number of the city you want to travel to."
    Write-Host "Traveling to another city takes a day."
    Write-Host
    Write-Host "Quit"
    Write-Host "----"
    Write-Host "This exits the game."
    Write-Host
    Write-Host "Random Events"
    Write-Host "-------------"
    Write-Host "Random events can occur at any time."
    Write-Host "Some are good, some are bad."
    Write-Host
    PressEnterPrompt
}

# This function displays tag line prompt (for title screen)
function ShowTaglinePrompt {
    param (
        [string]$Text
    )

    # Define an array of taglines to be used for the text
    $tagLines = @(
        '"My version is better." - John E. Dell',
        'In Drug Wars, it''s not personal; it''s strictly business.',
        'Red pill or Blue pill? Why not both?',
        'To infinity and beyond (the law).',
        'Life is like a box of narcotics; you never know what you''re gonna get.',
        'There''s no crying In Drug Wars!',
        'I see dead people... dealing drugs in Drug Wars.',
        'Frankly, my dear, I don''t give a gram.',
        'We''re gonna need a bigger syndicate.',
        'Keep your friends close and your narcotics closer.',
        'In Drug Wars, the first rule is you do talk about Drug Wars.',
        'I''ll be back... after I conquer the drug trade.',
        'Where every decision could be your last.',
        'The stakes have never been higher. (Get it?)',
        'In the shadows of a city gripped by vice, every move has consequences.',
        'Say hello to my little bag of weed.',
        'I feel the need... the need for speed! And by speed, I mean Amphetamines.',
        'May the force be with you, druggie.',
        'There''s no place like the seedy underbelly of a city.',
        '"Grandma loves it; reminds her of the good ol'' days." - Sarcastic Sally Says',
        '"Pixelated corner store trip. Play hide and seek with the cops!" - StonerGamer420',
        '"High scores as wild as my weekend. Like Mario Kart, but with banana peels." - Captain Cannabis',
        '"Monopoly''s side hustle. Laughed so hard, neighbours thought I was on something!" - ChuckleMaster69',
        '"Five stars for unexpected therapy!" - Johnny Two-eyes',
        '"In-game lawyer pricier than virtual stash. Legal drama with pixels, fewer objections." - The Gamer''s Ass',
        '"Meh" - Most People'
    )

    # If no text is supplied, randomly pick a tagline to use as $text
    if ([string]::IsNullOrEmpty($Text)) {
        $Text = Get-Random -InputObject $tagLines
        $useTagLines = $true
    }
    
    # Define an array of colors to be used for the text
    $colors = @("DarkGray", "Gray", "White", "Gray", "DarkGray", "Black")

    # Store the original cursor position
    $originalCursorPosition = $host.UI.RawUI.CursorPosition

    # Define the alternate text
    $alternateText = "Press Enter to begin"

    $counter = 1

    # Start an infinite loop
    while ($true) {
        # Loop through each color in the colors array
        foreach ($color in $colors) {
            # Reset the cursor position to the original position
            $host.UI.RawUI.CursorPosition = $originalCursorPosition
            
            # Write the text to the host with the current color, without a newline at the end
            if ($color -eq "Black") {
                # If the color is black, clear the line instead.
                Write-Centered (' ' * $Text.Length) -NoNewline
                $host.UI.RawUI.CursorPosition = $originalCursorPosition
            }
            else {
                Write-Centered $Text -ForegroundColor $color -NoNewline
            }

            # Set the sleep duration based on the current color
            $sleepDuration = 125
            if ($color -eq "White") {
                $sleepDuration *= 20
            }
            elseif ($color -eq "Black") {
                $sleepDuration *= 10
            }

            # Pause execution for the specified duration
            Start-Sleep -Milliseconds $sleepDuration

            # Check if a key has been pressed
            if ([System.Console]::KeyAvailable) {
                # Read the key that was pressed
                $key = [System.Console]::ReadKey($true)
                # If the Enter key was pressed, exit the loop
                if ($key.Key -eq "Enter") {
                    Write-Host
                    # Exit the function
                    return
                }
            }
        }

        # Swap the text and the alternate text
        if ($useTagLines) {
            if ($counter % 2 -eq 0) {
                $Text = Get-Random -InputObject $tagLines
            }
            else {
                $Text = $alternateText
            }
            $counter++
        }
        else {
            $temp = $Text
            $Text = $alternateText
            $alternateText = $temp
        }
    }
}

# Function to show the title screen
function ShowTitleScreen {
    $titleBlocks = @(
        @(
            ' (                                                    ____',
            ' )\ )                      (  (                      |   /',
            '(()/(   (      (   (  (    )\))(   ''    )  (         |  /',
            ' /(_))  )(    ))\  )\))(  ((_)()\ )  ( /(  )(   (    | /',
            '(_))_  (()\  /((_)((_))\  _(())\_)() )(_))(()\  )\   |/',
            ' |   \  ((_)(_))(  (()(_) \ \((_)/ /((_)_  ((_)((_) (',
            ' | |) || ''_|| || |/ _` |   \ \/\/ / / _` || ''_|(_-< )\',
            ' |___/ |_|   \_,_|\__, |    \_/\_/  \__,_||_|  /__/((_)',
            '                  |___/'
        ),
        @(
            '________                           __      __                       ._.',
            '\______ \ _______  __ __   ____   /  \    /  \_____  _______  ______| |',
            ' |    |  \\_  __ \|  |  \ / ___\  \   \/\/   /\__  \ \_  __ \/  ___/| |',
            ' |    `   \|  | \/|  |  // /_/  >  \        /  / __ \_|  | \/\___ \  \|',
            '/_______  /|__|   |____/ \___  /    \__/\  /  (____  /|__|  /____  > __',
            '        \/              /_____/          \/        \/            \/  \/'
        ),
        @(
            ' _______  .______       __    __    _______    ____    __    ____  ___      .______           _______. __',
            '|       \ |   _  \     |  |  |  |  /  _____|   \   \  /  \  /   / /   \     |   _  \         /       ||  |',
            '|  .--.  ||  |_)  |    |  |  |  | |  |  __      \   \/    \/   / /  ^  \    |  |_)  |       |   (----`|  |',
            '|  |  |  ||      /     |  |  |  | |  | |_ |      \            / /  /_\  \   |      /         \   \    |  |',
            '|  ''--''  ||  |\  \----.|  `--''  | |  |__| |       \    /\    / /  _____  \  |  |\  \----..----)   |   |__|',
            '|_______/ | _| `._____| \______/   \______|        \__/  \__/ /__/     \__\ | _| `._____||_______/    (__)'
        ),
        @(
            '    ,---,',
            '  .''  .'' `\',
            ',---.''     \   __  ,-.         ,--,',
            '|   |  .`\  |,'' ,''/ /|       ,''_ /|  ,----._,.',
            ':   : |  ''  |''  | |'' |  .--. |  | : /   /  '' /',
            '|   '' ''  ;  :|  |   ,'',''_ /| :  . ||   :     |',
            '    | ;  .  |''  :  /  |  '' | |  . .|   | .\  .',
            '|   | :  |  ''|  | ''   |  | '' |  | |.   ; '';  |',
            '    : | /  ; ;  : |   :  | : ;  ; |''   .   . |',
            '|   | ''` ,/  |  , ;   ''  :  `--''   \`---`-''| |',
            ';   :  .''     ---''    :  ,      .-./.''__/\_: |     ,---,',
            '|   ,.''                `--`----''    |   :    :  ,`--.'' |',
            '---''      .---.                      \   \  /   |   :  :',
            '          /. ./|                      `--`-''    ''   ''  ;',
            '      .--''.  '' ;             __  ,-.            |   |  |',
            '     /__./ \ : |           ,'' ,''/ /|  .--.--.   ''   :  ;',
            ' .--''.  ''   \'' .  ,--.--.  ''  | |'' | /  /    ''  |   |  ',
            '/___/ \ |    '' '' /       \ |  |   ,''|  :  /`./  ''   :  |',
            ';   \  \;      :.--.  .-. |''  :  /  |  :  ;_    ;   |  ;',
            ' \   ;  `      | \__\/: . .|  | ''    \  \    `. `---''. |',
            '  .   \    .\  ; ," .--.; |;  : |     `----.   \ `--..`;',
            '   \   \   '' \ |/  /  ,.  ||  , ;    /  /`--''  /.--,_',
            '    :   ''  |--";  :   .''   \---''    ''--''.     / |    |`.',
            '     \   \ ;   |  ,     .-./          `--''---''  `-- -`, ;',
            '      ''---"     `--`---''                          ''---`"'''
        )
    )
    
    # Change the foreground and background colors to gray and black
    $host.UI.RawUI.ForegroundColor = "Gray"
    $host.UI.RawUI.BackgroundColor = "Black"
    Clear-Host

    # Pick a random title block
    [string[]]$titleBlock = Get-Random -InputObject $titleBlocks

    # Figure out how many characters wide the longest line is.
    $longestLineLength = 0
    $titleBlock | ForEach-Object {
        if ($_.Length -gt $longestLineLength) {
            $longestLineLength = $_.Length
        }
    }

    $blockHeight = $titleBlock.Length

    # Based on the console height and width print the block centered verticalland horizontally
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $consoleHeight = $Host.UI.RawUI.WindowSize.Height

    # Calculate the left padding
    $leftPadding = [math]::Floor(($consoleWidth - $longestLineLength) / 2)

    # Calculate the top padding
    $topPadding = [math]::Floor(($consoleHeight - $blockHeight) / 2)

    # Remove a line from the padding to make room for tagline
    $topPadding -= 1

    # Ensure top padding is not negative
    $topPadding = [math]::max(0, $topPadding)
    # Add top padding
    1..$topPadding | ForEach-Object { Write-Host }

    # Randomly pick a colour for the block
    $foreColour = Get-Random -InputObject @('DarkBlue', 'DarkGreen', 'DarkRed', 'White')

    # Print the block
    $titleBlock | ForEach-Object {
        Write-Host (' ' * $leftPadding) $_ -ForegroundColor $foreColour
    }

    Write-Host
    ShowTaglinePrompt
}

# Function to load the high scores from the highscores.json file
function GetHighScores {
    $highScores = @()
    if (Test-Path -Path "highscores.json") {
        $highScores = Get-Content -Path "highscores.json" | ConvertFrom-Json
    }
    else {
        # Create default high score file with 10 made up initals and scores between 1000 and 100000
        $highScores = 1..10 | ForEach-Object {
            [PSCustomObject]@{
                # Generate 3 random uppercase letters for the initals.
                Initials = ('{0}{1}{2}' -f [char](Get-Random -Minimum 65 -Maximum 91), [char](Get-Random -Minimum 65 -Maximum 91), [char](Get-Random -Minimum 65 -Maximum 91))
                # Generate a random number between 1000 and 100000 that is a multiple of 10
                Score    = [int][Math]::Ceiling((Get-Random -Minimum 1000 -Maximum 100001) / 10) * 10
                Date     = (Get-Date).ToString("yyyy-MM-dd")
            }
        }

        # Save them to the json file
        $highScores | ConvertTo-Json | Out-File -FilePath "highscores.json" -Force
    }
    return $highScores | Sort-Object -Property Score -Descending
}

# Check if given score will make it onto the high score list
function IsHighScore {
    param (
        [Parameter(Mandatory = $true)]
        [int]$Score
    )

    $highScores = @(GetHighScores)
    $lowerScore = $highScores | Where-Object { $_.Score -lt $Score } | Select-Object -First 1

    return $null -ne $lowerScore
}

# Function to add a new score to the high scores list
function AddHighScore {
    param (
        [Parameter(Mandatory = $true)]
        [int]$Score, 
        [Parameter(Mandatory = $true)]
        [string]$Initials
    )
    
    $highScores = @(GetHighScores)
    $newScore = [PSCustomObject]@{
        Initials = $Initials
        Score    = $Score
        Date     = (Get-Date).ToString("yyyy-MM-dd")
    }
    $highScores += $newScore
    
    # Sort the high scores by score, descending, and keep the top 10
    $highScores | Sort-Object -Property Score -Descending | Select-Object -First 10 | ConvertTo-Json | Out-File -FilePath "highscores.json" -Force
}

# Function to advance to the game day
function AdvanceGameDay {
    param (
        [int]$Days = 1,
        [switch]$ChangeOutfit,
        [switch]$SkipPriceUpdate
    )

    # Advance the game day
    $script:Player.GameDay += $Days
    Write-Centered ('Welcome to day {0}! ({1} days left)' -f $script:Player.GameDay, ($script:GameDays - $script:Player.GameDay)) -ForegroundColor Yellow

    # Change your clothes
    if ($ChangeOutfit) {
        $clothesChangePhrases = @(
            'Yo, gotta switch up the fit, you know?',
            'Rollin'' with the fashion vibes, gotta keep them threads on point, staying icy for the streets, man.',
            'It''s all about that wardrobe rotation, staying lit and rockin'' those looks that scream realness, keeping it one hunnid, ya feel?',
            '''Cuz you gotta keep them threads fresh, homey.'
        )

        # Change the player's outfit, and capture the new outfit name.
        $newOutfit = $script:Player.ChangeOutfit()
        Write-Centered ('You change your clothes, putting on your favourite {0}.' -f $newOutfit)
        Start-Sleep -Milliseconds 500
        Write-Centered ('{0}' -f (Get-Random -InputObject $clothesChangePhrases)) -ForegroundColor DarkGray
    }

    if (!$SkipPriceUpdate) {
        # Randomize the drug prices for the day
        SetDrugPriceMultiplier
    }
    
}

# This function sets a random price multiplier for each drug in the game.
function SetDrugPriceMultiplier {
    $drugs = $script:GameDrugs
    foreach ($drug in $drugs) {
        $drug.PriceMultiplier = Get-Random -Minimum 0.5 -Maximum 2.6
    }
}

##############################
#endregion Function Definitions
################################

#################
# Main Entry Point
###################

# Set default error action
$ErrorActionPreference = 'Stop'

# Confirm that the console window is large enough to display the game.
if (!$SkipConsoleSizeCheck) {
    CheckConsoleSize
}

$script:Playing = $true

while ($script:Playing) {
    # Show title screen
    ShowTitleScreen

    # Initialize game state.
    InitGame

    # Main game loop.
    while (!$script:GameOver) {
        $choice = ShowMainMenu
        switch ($choice) {
            "B" {
                ShowBuyDrugsMenu
            }
            "S" {
                ShowSellDrugsMenu
            }
            "J" {
                Jet
            }
            "Q" {
                QuitGame
            }
            "?" {
                ShowHelp
            }
            "D" {
                ShowDrugopedia
            }
            "!" {
                StartRandomEvent
            }
            default {
                Write-Host 'Invalid choice'
                Start-Sleep -Milliseconds 500
            }
        }

        # User is quitting, or the game is over, break out of the loop.
        if ((!$script:Playing) -or $script:GameOver) {
            break
        }

        # Random events have a 10% chance of happening each day.
        if ($script:RandomEvents -and (Get-Random -Maximum 100) -lt $script:RandomEventChance_Current) {
            StartRandomEvent

            # Each time one random event fires off, the chance of getting another that day is halved.
            $script:RandomEventChance_Current = [math]::Floor($script:RandomEventChance_Current / 2)

            # If the chance is less than 1% set it to 0.
            if ($script:RandomEventChance_Current -lt 1) {
                $script:RandomEventChance_Current = 0
            }
        }

        # No cash and no drugs, game over
        if ($script:Player.Cash -le 0 -and $script:Player.Drugs.Count -eq 0) {
            Write-Centered 'You''re broke and you have no drugs left.' -ForegroundColor DarkRed
            Write-Centered 'You''re not really cut out for this business.' -ForegroundColor DarkGray
            Write-Host
            Write-BlockLetters 'Game over.' -ForegroundColor Black -BackgroundColor DarkRed -VerticalPadding 1 -Align Center
            Write-Host
            PressEnterPrompt
            EndGame
        }

        # Out of days, game over.
        if ($script:Player.GameDay -gt $script:GameDays) {
            Write-BlockLetters ('Day {0}!' -f $script:GameDays) -ForegroundColor Yellow -VerticalPadding 1 -Align Center
            Write-Host
            Write-Centered 'Time''s up!' -ForegroundColor Green
            Write-Host
            Write-Host
            PressEnterPrompt
            EndGame
        }
    }
}