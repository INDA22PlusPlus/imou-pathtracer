#include <stdio.h>
#include "cpu_obj.h"


int dump_robj(const char* filename, rsphere* rspheres, uint8_t rsphere_num,
                rplane* rplanes, uint8_t rplane_num, rlight* rlights,
                uint8_t rlight_num) {

    FILE* fp = fopen(filename, "wb");
    if (!fp) {
        return 0;
    }

    /* First byte is the number of elements which is followed by the raw data
       of the structs array. The order is rsphere, rplane, rlight*/
    fwrite(&rsphere_num, 1, 1, fp);
    fwrite(rspheres, sizeof(rsphere), rsphere_num, fp);

    fwrite(&rplane_num, 1, 1, fp);
    fwrite(rplanes, sizeof(rplane), rplane_num, fp);

    fwrite(&rlight_num, 1, 1, fp);
    fwrite(rlights, sizeof(rlight), rlight_num, fp);

    fclose(fp);

    return 1;
}

void extract_robj(const char* filename, rsphere** rspheres, uint8_t* rsphere_num,
                    rplane** rplanes, uint8_t* rplane_num, rlight** rlights,
                    uint8_t* rlight_num) {

    FILE* fp = fopen(filename, "rb");
    if (!fp) {
        return;
    }

    /* First byte is the number of elements which is followed by the raw data
       of the structs array. The order is rsphere, rplane, rlight*/

    fread(rsphere_num, 1, 1, fp);
    *rspheres = malloc((*rsphere_num) * sizeof(rsphere));
    fread(*rspheres, sizeof(rsphere), *rsphere_num, fp);

    fread(rplane_num, 1, 1, fp);
    *rplanes = malloc((*rplane_num) * sizeof(rplane));
    fread(*rplanes, sizeof(rplane), *rplane_num, fp);

    fread(rlight_num, 1, 1, fp);
    *rlights = malloc((*rlight_num) * sizeof(rlight));
    fread(*rlights, sizeof(rlight), *rlight_num, fp);

    fclose(fp);
}