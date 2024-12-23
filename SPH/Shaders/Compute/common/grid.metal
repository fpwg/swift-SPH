//
//  grid.metal
//  SPH
//
//  Created by Florian Plaswig on 23.12.24.
//

#include <metal_stdlib>
#include "../../definitions.h"
#include "grid.h"

using namespace metal;

int2 ParticleHashGrid::getGridPosition(float2 position) {
    return int2(floor(position / this->gridCellSize));
}

// TODO: work on this implementation
uint ParticleHashGrid::hash(int2 gridPosition) {
    int2 i = gridPosition * this->hashParams;
    return ((uint) (i.x + i.y)) % this->maximumHash;

}

void ParticleHashGrid::updateParticleHash(device particle &p) {
    p.cellHash = this->hash(getGridPosition(p.position));
}


NeighbourhoodIterator ParticleHashGrid::getNeighbourhoodIterator(device particle *particles, device const uint *cellStarts, float2 position) {
    int2 gridPosition = getGridPosition(position);
    return NeighbourhoodIterator(*this, particles, cellStarts, gridPosition);
}


NeighbourhoodIterator::NeighbourhoodIterator(ParticleHashGrid grid,
                             device particle *particles,
                             device const uint *cellStarts,
                             int2 gridPos) : grid(grid), particles(particles), cellStarts(cellStarts), ofGridPosition(gridPos) {
    int2 cellPosition = gridPos + cellOffsets[offsetIndex];
    uint cellHash = grid.hash(cellPosition);
    uint cellStart = cellStarts[cellHash];
    
    while (cellStart < 0 || cellStart >= grid.getMaximumHash()) { // empty cell
        offsetIndex++;
        
        if (offsetIndex >= 9) { // done
            done = true; return;
        }
        
        cellPosition = gridPos + cellOffsets[offsetIndex];
        cellHash = grid.hash(cellPosition);
        cellStart = cellStarts[cellHash];
    }
    
    currentIndex = cellStart;
}


void NeighbourhoodIterator::next() {
    if (done) { return; }
    uint nextIndex = currentIndex + 1;
    
    if (particles[currentIndex].cellHash != particles[nextIndex].cellHash) { // end of cell reached
        
        if (offsetIndex >= 8) { // end of cell offsets reached
            done = true;
            return;
        }
        
        offsetIndex++;
        int2 cellPosition = ofGridPosition + cellOffsets[offsetIndex];
        uint cellHash = grid.hash(cellPosition);
        uint cellStart = cellStarts[cellHash];
        
        while (cellStart < 0 || cellStart >= grid.getMaximumHash()) { // empty cell
            offsetIndex++;
            
            if (offsetIndex >= 9) { // done
                done = true;
            }
            
            cellPosition = ofGridPosition + cellOffsets[offsetIndex];
            cellHash = grid.hash(cellPosition);
            cellStart = cellStarts[cellHash];
        }
                       
        nextIndex = cellStarts[cellHash];
    }
    
    currentIndex = nextIndex;
}
