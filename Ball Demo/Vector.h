/*
  Copyright (C) 2008 Alex Diener

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  Alex Diener adiener@sacredsoftware.net
*/

#ifndef __VECTOR_H__
#define __VECTOR_H__

typedef struct Vector Vector;

struct Vector {
	float x;
	float y;
	float z;
};

Vector Vector_withValues(float x, float y, float z);

void Vector_normalize(Vector * vector);
Vector Vector_normalized(Vector vector);

float Vector_magnitude(Vector vector);
float Vector_magnitudeSquared(Vector vector);
Vector Vector_add(Vector vector1, Vector vector2);
Vector Vector_subtract(Vector vector1, Vector vector2);
float Vector_dot(Vector vector1, Vector vector2);
Vector Vector_cross(Vector vector1, Vector vector2);

#endif
