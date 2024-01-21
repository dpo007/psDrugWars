# Simulated Drug Wars Interaction

$playerMoney = 100
$playerInventoryCount = 50
$playerWeaponStrength = Get-Random -Minimum 1 -Maximum 11

#region Function Definitions

# Function to simulate getting arrested
function GetArrested {
    Write-Host "You get arrested!"
    $playerInventoryCount = 0  # Lose all inventory
}

# Function to simulate getting shot dead by cops
function GetShotDead {
	$shotDeadStrings = @(
		"The cops shoot you dead!",
		"The pigs spray you with lead!",
		"The cops turn you into a human pinata!",
		"The pigs serve you a hot plate of justice!",
		"The flatfoots send you on a one-way ticket to the afterlife!",
		"The pigs give you a front-row seat to the great beyond!",
		"The flatfoots send you on an express elevator to the afterlife!",
		"The cops give you a golden ticket to paradise!",
		"The flatfoots whisk you away on a magical mystery tour of the great beyond!",
		"The pigs upgrade your ticket to first class on the cosmic express!",
		"The flatfoots give you a VIP pass to the celestial realm!"
	)

    Write-Host (Get-Random -InputObject $shotDeadStrings)
    $playerMoney = 0
    $playerInventoryCount = 0
}

# Function to calculate the number of cops based on player money and inventory
function CalculateCops {
    $numCopsMoney = [math]::Ceiling($playerMoney / 5000)
    $numCopsInventory = [math]::Ceiling($playerInventoryCount / 50)

    # Add the two calculated values to get the total number of cops
    $totalCops = $numCopsMoney + $numCopsInventory
    return [math]::Max($totalCops, 1)
}

# Function to simulate a cop encounter
function SimulateCopEncounter {
    # Calculate the number of cops
    $numCops = CalculateCops

    # Display encounter message
    Write-Host "You encounter $numCops police officer(s)!"

    # Display player weapon level
    Write-Host "Your weapon level: $playerWeaponStrength"

    # Display options
    Write-Host "1. Attempt to bribe"
    Write-Host "2. Try to flee"
    Write-Host "3. Fight"

    # Get player choice
    $choice = Read-Host "Select an option (1, 2, or 3)"

    # Calculate the chance of getting shot (10% + 2% per cop)
    $shotChance = 10 + ($numCops * 2)

    # Process player choice
    switch ($choice) {
        1 {
            # Attempt to bribe
            $bribeAmount = $numCops * 250

            if ($playerMoney -ge $bribeAmount) {
                Write-Host "Bribe successful! You avoid legal consequences."
                $playerMoney -= $bribeAmount
            } else {
                Write-Host "Bribe failed! You don't have enough money to bribe all the cops."
                GetArrested
            }
        }
        2 {
            # Try to flee
            $fleeSuccess = [bool](Get-Random -Maximum 2)

            if ($fleeSuccess) {
                Write-Host "You successfully flee from the police!"
            } else {
                Write-Host "Flee attempt failed! The cop(s) catch you."
                # Calculate the chance of getting shot
                if (Get-Random -Maximum 100 -lt $shotChance) {
                    GetShotDead
                } else {
                    GetArrested
                }
            }
        }
        3 {
            # Try to fight
            # +%5 chance of success for each weapon strength
            $fightSuccess = [bool](Get-Random -Maximum 100 -lt ($playerWeaponStrength * 5))

            if ($fightSuccess) {
                Write-Host "You win the fight and avoid legal consequences."
            } else {
                Write-Host "You lose the fight! The cop(s) arrest you."
                # Calculate the chance of getting shot
                if (Get-Random -Maximum 100 -lt $shotChance) {
                    GetShotDead
                } else {
                    GetArrested
                }
            }
        }
        default {
            Write-Host "Invalid choice. Please select 1, 2, or 3."
        }
    }
}

#endregion

# Main game loop
while ($playerMoney -gt 0 -and $playerInventoryCount -gt 0) {
    # Simulate cop encounters during the game
    SimulateCopEncounter

    # Display player stats
    Write-Host "Current Stats:"
    Write-Host "Wealth: $playerMoney"
    Write-Host "Inventory: $playerInventoryCount"

    # Simulate other game events or actions here
    # ...

    # Pause for readability
    Read-Host "Press Enter to continue..."
}

# Display game over message
Write-Host "Game Over! Your journey has come to an end."
