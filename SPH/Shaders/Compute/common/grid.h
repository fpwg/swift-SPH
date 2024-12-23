//
//  grid.h
//  SPH
//
//  Created by Florian Plaswig on 23.12.24.
//

#ifndef grid_h
#define grid_h

constant int2 cellOffsets[9] = {
    int2(-1, -1), int2(-1, 0), int2(-1, 1),
    int2(0, -1), int2(0, 0), int2(0, 1),
    int2(1, -1), int2(1, 0), int2(1, 1)
};

class NeighbourhoodIterator;

class ParticleHashGrid {
    int2 hashParams = int2(37, 1297);
    float gridCellSize;
    uint maximumHash;
public:
    inline ParticleHashGrid(float gridCellSize, uint maximumHash) : gridCellSize(gridCellSize), maximumHash(maximumHash) {}
    
    void updateParticleHash(device particle &);
    int2 getGridPosition(float2);
    uint hash(int2);
    
    NeighbourhoodIterator getNeighbourhoodIterator(device particle*, device const uint*, float2);
    
    inline uint getMaximumHash() { return maximumHash; }
};

// Slightly unconventional iterator implementation; this is do to some constraints
// with pointers in metal. Might be made a bit more idiomatic in the future.
class NeighbourhoodIterator {
    ParticleHashGrid grid;
    device particle *particles;
    device const uint *cellStarts;

    int2 ofGridPosition;
    uint offsetIndex = 0;
    uint currentIndex = 0;
    
    bool done = false;
public:
    NeighbourhoodIterator(ParticleHashGrid, device particle*, device const uint*, int2);
    
    inline device particle& operator*() { return particles[currentIndex]; }
    inline device particle* operator->() { return &particles[currentIndex]; }
    inline bool hasNext() { return !done; }
    
    inline uint getCurrentIndex() {
        return currentIndex;
    }
    
    void next();
};




#endif /* grid_h */
