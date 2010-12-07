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

#ifndef __MATRIX_H__
#define __MATRIX_H__

typedef struct Matrix Matrix;

struct Vector;

struct Matrix {
	float m[16];
};

void Matrix_loadIdentity(Matrix * matrix1);
Matrix Matrix_identity();

Matrix Matrix_withValues(float m0,  float m4,  float m8,  float m12,
                         float m1,  float m5,  float m9,  float m13,
                         float m2,  float m6,  float m10, float m14,
                         float m3,  float m7,  float m11, float m15);
Matrix Matrix_fromDirectionVectors(struct Vector right, struct Vector up, struct Vector front);

void Matrix_multiply(Matrix * matrix1, Matrix matrix2);
Matrix Matrix_multiplied(Matrix matrix1, Matrix matrix2);

void Matrix_translate(Matrix * matrix1, float x, float y, float z);
Matrix Matrix_translated(Matrix matrix1, float x, float y, float z);

void Matrix_scale(Matrix * matrix, float x, float y, float z);
Matrix Matrix_scaled(Matrix matrix, float x, float y, float z);

void Matrix_rotate(Matrix * matrix, struct Vector axis, float angle);
Matrix Matrix_rotated(Matrix matrix, struct Vector axis, float angle);

void Matrix_shearX(Matrix * matrix, float y, float z);
Matrix Matrix_shearedX(Matrix matrix, float y, float z);

void Matrix_shearY(Matrix * matrix, float x, float z);
Matrix Matrix_shearedY(Matrix matrix, float x, float z);

void Matrix_shearZ(Matrix * matrix, float x, float y);
Matrix Matrix_shearedZ(Matrix matrix, float x, float y);

void Matrix_applyPerspective(Matrix * matrix, float fovY, float aspect, float zNear, float zFar);
Matrix Matrix_perspective(Matrix matrix, float fovY, float aspect, float zNear, float zFar);

void Matrix_transpose(Matrix * matrix);
Matrix Matrix_transposed(Matrix matrix);

float Matrix_determinant(Matrix matrix);

void Matrix_invert(Matrix * matrix);
Matrix Matrix_inverted(Matrix matrix);

struct Vector Matrix_multiplyVector(Matrix matrix, struct Vector vector);

#endif
