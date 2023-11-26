########################
#region Class Definitions
##########################
class Drug {
    [string]$Name
    [string]$Code
    [string]$Description
    hidden [int]$BasePrice
    [int[]]$PriceRange
    [float]$PriceMultiplier
    [int]$Quantity

    # Constructor that takes a drug name
    Drug([string]$Name) {
        $this.Name = $Name
        $this.Code = $script:DrugCodes.Keys | Where-Object { $script:DrugCodes[$_] -eq $Name }
        $this.PriceRange = $script:DrugsInfo[$this.Code]['PriceRange']
        $this.PriceMultiplier = 1.0
        $this.Quantity = 0
        $this.SetRandomBasePrice()
    }

    # Method to set the hidden BasePrice value to a random value from the drugs PriceRange, rounded to the nearest 10 dollars (Bankers' rounding).
    [void]SetRandomBasePrice() {
        $this.BasePrice = [math]::Round((Get-Random -Minimum $this.PriceRange[0] -Maximum $this.PriceRange[1]) / 10) * 10
    }

    # Calculate the price based on BasePrice and PriceMultiplier, rounded to the nearest 10 dollars (Bankers' rounding).
    [int]get_Price() {
        return [math]::Round($this.BasePrice * $this.PriceMultiplier / 10) * 10
    }

    # Method to set the hidden BasePrice value
    [void]set_BasePrice([int]$BasePrice) {
        $this.BasePrice = $BasePrice
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
    [int]$Pockets
    [int]$GameDay

    # Default constructor
    Player() {
        $this.Drugs = @()
        $this.Pockets = 0
        $this.GameDay = 1
    }

    # FreePockets method returns the number of pockets minus the total Quntity of all Drugs
    [int]get_FreePockets() {
        $totalQuantity = 0
        $this.Drugs | ForEach-Object { $totalQuantity += $_.Quantity }
        return $this.Pockets - $totalQuantity
    }

    # Method to add drugs to the player's Drugs collection.
    [void]AddDrugs([Drug]$Drug) {
        # Minimum Add is 1
        if ($Drug.Quantity -lt 1) {
            Write-Host 'You must add at least 1 of a drug.'
            return
        }

        # Check if there's enough free pockets
        if ($this.get_FreePockets() -ge $Drug.Quantity) {
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
    [void]RemoveDrugs([Drug]$Drug) {
        # If the player has some of the drug, remove the quantity from the existing drug, otherwise do nothing.
        $myMatchingDrug = $this.Drugs | Where-Object { $_.Name -eq $Drug.Name }
        if ($myMatchingDrug) {
            $myMatchingDrug.Quantity -= $Drug.Quantity
            if ($myMatchingDrug.Quantity -le 0) {
                $myMatchingDrug.Quantity = 0
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
                if ($Drug.Quantity -gt $this.get_FreePockets()) {
                    Write-Host ('You don''t have enough free pockets to hold that much {0}.' -f $Drug.Name)
                    break
                }
                # If the player has enough cash and free pockets, buy the drugs
                $this.Cash -= $totalPrice
                $this.AddDrugs($Drug)
                Write-Host ('You bought {0} {1} for ${2}.' -f $Drug.Quantity, $Drug.Name, $totalPrice)
            }
        }
        # Pause for 3 seconds before returning
        Start-Sleep 3
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
            # Check if the player's cash is more than $1000
            if ($script:Player.Cash -gt 1000) {
                # Calculate the bust chance. The base chance is 5%, and it increases by 5% for each $1000 over $1000 the player has.
                [float]$bustChance = 0.05 + (0.05 * (($script:Player.Cash - 1000) / 1000))

                # If the bust chance is greater than 60%, cap it at 60%
                if ($bustChance -gt 0.6) {
                    $bustChance = 0.6
                }

                # Generate a random decimal number between 0 and 1
                [float]$randomNumber = Get-Random -Minimum 0.0 -Maximum 1.0
                # If the random number is less than or equal to the bust chance, the cops bust the player
                if ($randomNumber -le $bustChance) {
                    Write-Centered 'You spent the night in jail and lost all your drugs.' -ForegroundColor Red
                    # Remove all drugs from the player's possession
                    $script:Player.Drugs = @()
                    # Increment the game day
                    $script:Player.GameDay++
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
            }
        }
    },
    @{
        "Name"        = "Flash Back"
        "Description" = "You trip out and lose a day!"
        "Effect"      = {
            Tripout
            $script:Player.GameDay++
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
            if ($script:Player.get_FreePockets() -ge 1) {
                if ($script:Player.get_FreePockets() -lt $giveAwayQuantity) {
                    Write-Centered ('You only have room for {0} pockets of free Hash.' -f $script:Player.get_FreePockets()) -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    Write-Centered 'But that''s still better than a kick in the ass''! :)'
                    $giveAwayQuantity = $script:Player.get_FreePockets()
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
                Write-BlockLetters '** BURN!! **' -ForegroundColor Black -BackgroundColor DarkRed -Align Center -VerticalPadding 1
                Start-Sleep -Seconds 2
            }
        }
    },
    @{
        "Name"        = "Bad Batch"
        "Description" = "You got a bad batch of drugs. You lose some cash trying to get rid of it."
        "Effect"      = {
            $loss = Get-Random -Minimum 100 -Maximum 501
            # Round the loss to the nearest 10 (Bankers' rounding).
            $loss = [math]::Round($loss / 10) * 10
            $script:Player.Cash -= $loss

            Start-Sleep -Seconds 2
            Write-Host
            Write-Centered ('You lost ${0}.' -f $loss) -ForegroundColor DarkRed
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
                    $script:Player.GameDay++
                }
                else {
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
                            Write-Centered ('You got so damn high, you actually GAINED A DAY!') -ForegroundColor DarkGreen
                            $script:GameDays++
                            Write-Host
                            Write-Centered ('You now have {0} days to make as much cash as possible.' -f $script:GameDays)
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
        "Name"        = "Cosmic Cargo Pants"
        "Description" = "Groovy, man! You stumbled upon these cosmic cargo pants, packed with pockets for all your trippy treasures!"
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            $extraPockets = Get-Random -Minimum 10 -Maximum 21
            $script:Player.Pockets += $extraPockets
            Write-Centered ('Far out! You''ve now got {0} extra pockets! Carryin'' more of your magic stash just got easier.' -f $extraPockets) -ForegroundColor DarkGreen
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Zen Hemp Backpack"
        "Description" = "Whoa, dude! Check out this Zen hemp backpack! It's like, totally eco-friendly and has space for all your good vibes and herbal remedies."
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            $extraPockets = 50
            $script:Player.Pockets += $extraPockets
            Write-Centered ('Dude, it can cradle {0} extra pockets worth of your good stuff. Mother Nature would be proud.' -f $extraPockets) -ForegroundColor DarkGreen
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Psychedelic Hemp Poncho"
        "Description" = "Far-out find, man! You snagged a tie-dyed hemp poncho. It's like wearing a kaleidoscope of good vibes!"
        "Effect"      = {
            Start-Sleep -Seconds 2
            Write-Host
            $extraPockets = 5
            $script:Player.Pockets += $extraPockets
            Write-Centered ('Trippy, right? This tie-dyed hemp poncho adds {0} extra pockets to your cosmic wardrobe. Carry on, peace traveler.' -f $extraPockets) -ForegroundColor DarkGreen
            Start-Sleep -Seconds 2
        }
    },
    @{
        "Name"        = "Skid-Row Lemonade Stand"
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
            Start-Sleep -Seconds 2
            $choice = Get-Random -Minimum 1 -Maximum 5
            $pocketCost = 20
            switch ($choice) {
                1 {
                    $extraPockets = 50
                    $extraPocketsCost = $pocketCost * $extraPockets
                    Write-Centered ('You encounter a cosmic, drugged-out vendor selling magical pockets. Spend ${0} to get {1} extra pockets? (Y/N)' -f $extraPocketsCost, $extraPockets)
                    if ($script:Player.Cash -ge $extraPocketsCost) {
                        # Wait for user to press a valid key
                        $choices = @('Y', 'N')
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        while (-not $choices.Contains($choice)) {
                            $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        }
                        if ($choice -eq 'Y') {
                            $script:Player.Cash -= $extraPocketsCost
                            $script:Player.Pockets += $extraPockets
                            Write-Centered 'You made a wise investment and gained 5 extra pockets!'
                        }
                        else {
                            Write-Centered 'You decide not to spend your cash, and the cosmic vendor fades away. No extra pockets for you.'
                        }
                    }
                    else {
                        Write-Centered 'You don''t have enough cash to buy the magical pockets. The cosmic vendor disappears in disappointment. No extra pockets for you.'
                    }
                }
                2 {
                    Write-Centered 'You meet a luded-out pocket guru who offers to enhance your inner pocket energy. Meditate for a chance to gain 10 extra pockets? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        $success = Get-Random -Minimum 0 -Maximum 2
                        if ($success -eq 1) {
                            $script:Player.Pockets += 10
                            Write-Centered 'After a deep meditation session, you feel your inner pocket energy expand. You gained 10 extra pockets!'
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
                    if ($script:Player.Pockets -lt 5) {
                        Write-Centered 'You see a DMT-induced alien shaman, but they''re uninterested in playing a game with someone who doesn''t even have 5 pockets. No extra pockets for you.'
                    }
                    else {
                        Write-Centered 'A mischievous DMT-induced alien shaman challenges you to a game. Win, and you gain 15 extra pockets. Lose, and you lose 5 pockets. Play the game? (Y/N)'
                        # Wait for user to press a valid key
                        $choices = @('Y', 'N')
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        while (-not $choices.Contains($choice)) {
                            $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                        }
                        if ($choice -eq 'Y') {
                            $win = Get-Random -Minimum 0 -Maximum 2
                            if ($win -eq 1) {
                                $script:Player.Pockets += 15
                                Write-Centered 'You outwit the alien shaman in a cosmic game of tic-tac-toe. You gained 15 extra pockets!'
                            }
                            else {
                                $script:Player.Pockets -= 5
                                Write-Centered 'The alien shaman proves to be a cunning opponent. You lose 5 pockets in the game. Better luck next time.'
                            }
                        }
                        else {
                            Write-Centered 'You decide not to play the game, and the alien shaman disappears in a puff of interdimensional smoke. No extra pockets for you.'
                        }
                    }
                }
                4 {
                    Write-Centered 'You find a field of magical pocket flowers. Smelling one might grant you extra pockets. Smell a flower? (Y/N)'
                    # Wait for user to press a valid key
                    $choices = @('Y', 'N')
                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    while (-not $choices.Contains($choice)) {
                        $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString().ToUpper()
                    }
                    if ($choice -eq 'Y') {
                        $pocketsToGain = Get-Random -Minimum 1 -Maximum 6
                        $script:Player.Pockets += $pocketsToGain
                        Write-Centered ('The magical dank kush aroma of the pocket flower works its wonders. You gained {0} extra pockets!' -f $pocketsToGain)
                    }
                    else {
                        Write-Centered 'You decide not to risk it, and the field of pocket flowers fades away. No extra pockets for you.'
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
                            $script:Player.GameDay++
                        }
                        else {
                            $script:Player.Cash += Get-Random -Minimum 20 -Maximum 501
                            Write-Centered ('The cocktail of {0} gives you an otherworldly experience.' -f $randomDrug.Name)
                            Start-Sleep -Seconds 2
                            Write-Centered ('You find some extra cash in your pocket (after you barf and come down)!') -ForegroundColor DarkGreen
                        }
                    }
                    else {
                        Write-Centered 'You decide to pass on the shady dealer''s offer, and they disappear into the shadows. No risk, no reward.'
                    }
                }
                2 {
                    Write-Centered 'A grizzled junkie challenges you to a game of street smarts. Accept the challenge? (Y/N)'
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
                            $script:Player.GameDay++
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
                        if ($script:Player.get_FreePockets() -ge $hashQuantity) {
                            Write-Host
                            Write-Centered ('As a bonus, the artist hands you {0} pockets of Hash.' -f $hashQuantity) -ForegroundColor DarkGreen
                            $script:Player.AddDrugs($hash)
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
    }    
)
#############################################
#endregion Define Script-Wide Lists and Tables
###############################################

###########################
#region Function Definitions
#############################
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

    # If the text is longer than the console width -2, split the Text into an array of multiple lines
    $textArray = @()
    # Check if the length of the text is greater than the console width minus 2
    if ($Text.Length -gt ($consoleWidth - 2)) {
        # Store the length of the text and the maximum line length
        $textLength = $Text.Length
        $lineLength = $consoleWidth - 2

        # Calculate the number of lines needed to display the text
        $lineCount = [math]::Ceiling($textLength / $lineLength)

        # Loop through each line
        for ($i = 0; $i -lt $lineCount; $i++) {
            # Calculate the start and end index for the substring
            $startIndex = $i * $lineLength
            $endIndex = [math]::Min(($i + 1) * $lineLength, $textLength)

            # Extract the line from the text
            $line = $Text.Substring($startIndex, $endIndex - $startIndex)

            # Check if the line exceeds the line length
            if ($line.Length -eq $lineLength) {
                # Find the last space in the line
                $lastSpaceIndex = $line.LastIndexOf(' ')

                # If a space was found, truncate the line at the last space
                if ($lastSpaceIndex -gt 0) {
                    $line = $line.Substring(0, $lastSpaceIndex)
                }
            }

            # Add the line to the text array
            $textArray += $line
        }
    }
    else {
        $textArray += $Text
    }

    # Iterate through each line in the array
    foreach ($line in $textArray) {
        # Calculate padding to center text
        $padding = [math]::Max(0, [math]::Floor((($Host.UI.RawUI.WindowSize.Width - $line.Length) / 2)))

        # Write text to console with padding, using the filtered parameters.
        Write-Host (' ' * $padding + $line) @filteredParams
    }
}

# Function to write large block letters to the console, based on provided text.
function Write-BlockLetters {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [ValidateSet("Left", "Center", "Right")]
        [string]$Align = "Left",
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::Gray,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [int]$VerticalPadding = 0
    )
    
    # Define the mapping of characters to their block letter representations
    $blockLetters = @{
        'A' = @(
            "  #  ",
            " # # ",
            "#####",
            "#   #",
            "#   #"
        )
        'B' = @(
            "#### ",
            "#   #",
            "#### ",
            "#   #",
            "#### "
        )
        'C' = @(
            " ### ",
            "#   #",
            "#    ",
            "#   #",
            " ### "
        )
        'D' = @(
            "#### ",
            "#   #",
            "#   #",
            "#   #",
            "#### "
        )
        'E' = @(
            "#####",
            "#    ",
            "#### ",
            "#    ",
            "#####"
        )
        'F' = @(
            "#####",
            "#    ",
            "#### ",
            "#    ",
            "#    "
        )
        'G' = @(
            " ### ",
            "#    ",
            "#  ##",
            "#   #",
            " ### "
        )
        'H' = @(
            "#   #",
            "#   #",
            "#####",
            "#   #",
            "#   #"
        )
        'I' = @(
            "#####",
            "  #  ",
            "  #  ",
            "  #  ",
            "#####"
        )
        'J' = @(
            "#####",
            "   # ",
            "   # ",
            "#  # ",
            " ##  "
        )
        'K' = @(
            "#   #",
            "#  # ",
            "###  ",
            "#  # ",
            "#   #"
        )
        'L' = @(
            "#    ",
            "#    ",
            "#    ",
            "#    ",
            "#####"
        )
        'M' = @(
            "#   #",
            "## ##",
            "# # #",
            "#   #",
            "#   #"
        )
        'N' = @(
            "#   #",
            "##  #",
            "# # #",
            "#  ##",
            "#   #"
        )
        'O' = @(
            " ### ",
            "#   #",
            "#   #",
            "#   #",
            " ### "
        )
        'P' = @(
            "#### ",
            "#   #",
            "#### ",
            "#    ",
            "#    "
        )
        'Q' = @(
            " ### ",
            "#   #",
            "# # #",
            "#  # ",
            " ## #"
        )
        'R' = @(
            "#### ",
            "#   #",
            "#### ",
            "# #  ",
            "#  ##"
        )
        'S' = @(
            " ####",
            "#    ",
            " ### ",
            "    #",
            "#### "
        )
        'T' = @(
            "#####",
            "  #  ",
            "  #  ",
            "  #  ",
            "  #  "
        )
        'U' = @(
            "#   #",
            "#   #",
            "#   #",
            "#   #",
            " ### "
        )
        'V' = @(
            "#   #",
            "#   #",
            "#   #",
            " # # ",
            "  #  "
        )
        'W' = @(
            "#   #",
            "#   #",
            "# # #",
            "## ##",
            "#   #"
        )
        'X' = @(
            "#   #",
            " # # ",
            "  #  ",
            " # # ",
            "#   #"
        )
        'Y' = @(
            "#   #",
            " # # ",
            "  #  ",
            "  #  ",
            "  #  "
        )
        'Z' = @(
            "#####",
            "   # ",
            "  #  ",
            " #   ",
            "#####"
        )
        '0' = @(
            " ### ",
            "#   #",
            "# # #",
            "#   #",
            " ### "
        )
        '1' = @(
            " # ",
            "## ",
            " # ",
            " # ",
            "###"
        )
        '2' = @(
            " ### ",
            "#   #",
            "  ## ",
            " #   ",
            "#####"
        )
        '3' = @(
            " ### ",
            "#   #",
            "  ## ",
            "#   #",
            " ### "
        )
        '4' = @(
            "#  # ",
            "#  # ",
            "#####",
            "   # ",
            "   # "
        )
        '5' = @(
            "#####",
            "#    ",
            "#### ",
            "    #",
            "#### "
        )
        '6' = @(
            " ### ",
            "#    ",
            "#### ",
            "#   #",
            " ### "
        )
        '7' = @(
            "#####",
            "   # ",
            "  #  ",
            " #   ",
            "#    "
        )
        '8' = @(
            " ### ",
            "#   #",
            " ### ",
            "#   #",
            " ### "
        )
        '9' = @(
            " ### ",
            "#   #",
            " ####",
            "    #",
            " ### "
        )
        '.' = @(
            "   ",
            "   ",
            "   ",
            "   ",
            " # "
        )
        '?' = @(
            " ### ",
            "#   #",
            "   # ",
            "     ",
            "  #  "
        )
        '!' = @(
            "##",
            "##",
            "##",
            "  ",
            "##"
        )
        '$' = @(
            " ### ",
            "# #  ",
            " ### ",
            "  # #",
            " ### "
        )
        '-' = @(
            "    ",
            "    ",
            "####",
            "    ",
            "    "
        )
        '+' = @(
            "   ",
            " # ",
            "###",
            " # ",
            "   "
        )
        '=' = @(
            "    ",
            "####",
            "    ",
            "####",
            "    "
        )
        '_' = @(
            "    ",
            "    ",
            "    ",
            "    ",
            "####"
        )
        ' ' = @(
            "  ",
            "  ",
            "  ",
            "  ",
            "  "
        )
        '<' = @(
            "  #",
            " # ",
            "#  ",
            " # ",
            "  #"
        )
        '>' = @(
            "#  ",
            " # ",
            "  #",
            " # ",
            "#  "
        )
        '@' = @(
            " ### ",
            "#   #",
            "# ###",
            "# # #",
            " ### "
        )
        '#' = @(
            " # # ",
            "#####",
            " # # ",
            "#####",
            " # # "
        )
        '%' = @(
            "#   #",
            "   # ",
            "  #  ",
            " #   ",
            "#   #"
        )
        '^' = @(
            " # ",
            "# #",
            "   ",
            "   ",
            "   "
        )
        '&' = @(
            " ##  ",
            "#  # ",
            " ##  ",
            "#  # ",
            " ## #"
        )
        '*' = @(
            "  #  ",
            "# # #",
            " ### ",
            "# # #",
            "  #  "
        )
        '(' = @(
            " #",
            "# ",
            "# ",
            "# ",
            " #"
        )
        ')' = @(
            "# ",
            " #",
            " #",
            " #",
            "# "
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

    # Add blank vertical padding lines to the top and bottom $lines array that are as wide as the longest line
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
            $rightPadding = $consoleWidth - $longestLine - $leftPadding
        }
        "Right" {
            $leftPadding = $consoleWidth - $longestLine
        }
    }
    
    # Write the lines to the console with the padding
    $lines | ForEach-Object {
        $line = $_
        if ($Align -eq "Center") {
            # Right padding is added so we can fill it with spaces/background colour when using centered alignment.
            $line = (" " * $leftPadding) + $line + (" " * $rightPadding)
        }
        else {
            $line = (" " * $leftPadding) + $line
        }
    
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
    
        # Add New Line to end.
        Write-Host
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

    # Create and populate the drugs available for this game session.
    [Drug[]]$script:GameDrugs = InitGameDrugs -DrugCount $gameDrugCount

    # Create and populate the cities available for this game session.
    [City[]]$script:GameCities = InitGameCities -CityCount $cityCount -MaxDrugCount $cityDrugCount

    # Create player object, and populate with game-starting values.
    [Player]$script:Player = [Player]::new()
    $script:Player.Cash = $startingCash
    $script:Player.City = $script:GameCities | Get-Random
    $script:Player.Pockets = $startingPockets

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
    Write-centered ('Cash: ${0} :: Free Pockets: {1}/{2}' -f $script:Player.Cash, $script:Player.get_FreePockets(), $script:Player.Pockets)
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
    Write-Centered '-----------'
    Write-Centered 'Drugopedia'
    Write-Centered '-----------'
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
    Write-Host 'Your drugs:'
    if ($script:Player.Drugs.Count -eq 0) {
        Write-Host '· You have 0 marijuanas.'
    }
    else {
        $script:Player.Drugs | ForEach-Object {
            Write-Host ('· {0}: {1}' -f $_.Name, $_.Quantity)
        }
    }
    Write-Host
    Write-Host "[B]uy drugs"
    Write-Host "[S]ell drugs"
    Write-Host "[J]et to another city"
    Write-Host
    Write-Host "[Q]uit"
    Write-Host "[?]Help"
    Write-Host
    Write-Host "What now, boss? " -NoNewline

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
    Write-Host "Enter the number of the drug you want to buy (1-$drugCount, or 'Q' to return to the main menu) " -NoNewline
    $drugNumber = $null
    while (-not $drugNumber) {
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character.ToString()
        switch ($key) {
            { $_ -in '1'.."$drugCount" } { $drugNumber = [int]$key; break }
            { $_ -in 'q', 'Q' } { return }
        }
    }

    Write-Host
    $drugToBuy = $script:Player.City.Drugs[$drugNumber - 1]
    $maxQuantity = [math]::Floor($script:Player.Cash / $drugToBuy.get_Price())

    # Ask how many they want to buy.
    $quantity = Read-Host "Enter the quantity you want to buy (max $maxQuantity)"
    $quantityInt = 0
    if (-not [int]::TryParse($quantity, [ref]$quantityInt) -or $quantityInt -lt 1) {
        Write-Host "Invalid quantity."
        return
    }

    # Buy the drugs.
    $drugToBuy.Quantity += $quantityInt
    $script:Player.BuyDrugs($drugToBuy)
    
    Write-Host "Transaction complete"
    PressEnterPrompt
}

# This function displays the drug selling menu.
function ShowSellDrugsMenu {
    Clear-Host
    Write-Host "Sell Drugs"
    Write-Host "----------"
    $script:PlayerDrugs.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Key): $($_.Value)"
    }
    $drugName = Read-Host "Enter the name of the drug you want to sell"
    if (-not $script:PlayerDrugs.ContainsKey($drugName)) {
        Write-Host "You don't have any $drugName"
        return
    }
    $drugQuantity = $script:PlayerDrugs[$drugName]
    $drugPrice = $drugPrices[$drugName]
    $quantity = Read-Host "Enter the quantity you want to sell (max $drugQuantity)"
    $quantityInt = 0
    if (-not [int]::TryParse($quantity, [ref]$quantityInt)) {
        Write-Host "Invalid quantity"
        return
    }
    if ($quantityInt -gt $drugQuantity) {
        Write-Host "Quantity exceeds your inventory"
        return
    }
    $totalPrice = $quantityInt * $drugPrice
    $script:Player.Cash += $totalPrice
    $script:PlayerDrugs[$drugName] -= $quantityInt
    if ($script:PlayerDrugs[$drugName] -eq 0) {
        $script:PlayerDrugs.Remove($drugName)
    }
    Write-Host "Transaction complete"
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

    $newCity = $null
    Write-Host "Enter the city you want to jet to (1-$cityCount, or 'Q' to return to the main menu) " -NoNewline
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

    # If the new city is differnt from the current city, then travel to the new city.
    if ($script:Player.City -ne $alphabetizedCities[$newCity - 1]) {
        # Set player's new location.
        $script:Player.City = $alphabetizedCities[$newCity - 1]

        # Fill landing City with random drugs.
        $script:Player.City.Drugs = $script:GameDrugs | Get-Random -Count $script:Player.City.MaxDrugCount

        # Travel takes a day.
        $script:Player.GameDay++
    }
    else {
        Write-Host
        Write-Centered ('Lay off your stash man!  You''re already in {0}!' -f $script:Player.City.Name)
        Start-Sleep 2
        PressEnterPrompt
    }
}

# This function handles a random event.
function StartRandomEvent {
    $randomEvent = $script:RandomEvents | Get-Random

    Clear-Host
    ShowMenuHeader
    Write-Host
    $eventName = ('{0}!' -f $randomEvent.Name)
    Write-BlockLetters $eventName -Align Center
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
        Clear-Host
        Write-Host
        $days = $script:Player.GameDay
        $daysLabel = if ($days -eq 1) { 'day' } else { 'days' }
        Write-Centered ('You survived {0} {1}, and ended up with ${2} in cash.' -f $days, $daysLabel, $script:Player.Cash)
        Write-Host
        Write-BlockLetters 'Thanks for playing!' -Align Center -BackgroundColor Blue -VerticalPadding 1
        Write-Host
        Write-Host
        Write-Host
        exit
    }

    return    
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
##############################
#endregion Function Definitions
################################

#################
# Main Entry Point
###################

# Set default error action
$ErrorActionPreference = 'Stop'

# Initialize game state.
InitGame

# Main game loop.
while ($true) {
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
    if ($script:RandomEvents -and (Get-Random -Maximum 100) -lt 10) {
        StartRandomEvent
    }
    if ($script:Player.Cash -lt 0) {
        Write-Centered 'You ran out of cash.  Game over.' -ForegroundColor Red
        QuitGame
    }
    if ($script:Player.GameDay -gt $script:GameDays) {
        Write-Centered ('Time''s up!  Game over.' -f $script:GameDays) -ForegroundColor DarkGreen
        QuitGame
    }
}
