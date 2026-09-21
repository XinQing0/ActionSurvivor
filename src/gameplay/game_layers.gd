extends Object

## Physics layer bits shared by every gameplay body.
##
## Enemies collide only with each other so the crowd separates without shoving
## the player. Contact damage is resolved by an explicit distance check in
## `enemy.gd` instead of by physics, which keeps it deterministic and easy to
## move behind a server authority later.

const PLAYER := 1 << 0
const ENEMY := 1 << 1
const PROJECTILE := 1 << 2
