# Pagy 9 Configuration for ENMA AI
require "pagy"
require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 20
Pagy::DEFAULT[:overflow] = :last_page
