import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
export class PaginationDto {
  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;
  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 50 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;
  @ApiPropertyOptional({
    enum: [
      'createdAt',
      'name',
      'startsAt',
      'registeredAt',
      'title',
      'email',
      'joinedAt',
    ],
  })
  @IsOptional()
  @IsEnum([
    'createdAt',
    'name',
    'startsAt',
    'registeredAt',
    'title',
    'email',
    'joinedAt',
  ])
  sortBy?: string;
  @ApiPropertyOptional({ enum: ['asc', 'desc'], default: 'desc' })
  @IsEnum(['asc', 'desc'])
  sortOrder: 'asc' | 'desc' = 'desc';
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
export function pagination(
  q: PaginationDto,
  allowed: string[] = ['createdAt'],
) {
  if (q.sortBy && !allowed.includes(q.sortBy))
    throw new ApiError(
      'VALIDATION_ERROR',
      `Permitted sortBy: ${allowed.join(', ')}`,
    );
  return {
    skip: (q.page - 1) * q.limit,
    take: q.limit,
    orderBy: { [q.sortBy ?? allowed[0]]: q.sortOrder },
  };
}
export function page<T>(data: T[], total: number, q: PaginationDto) {
  return {
    data,
    meta: {
      page: q.page,
      limit: q.limit,
      total,
      totalPages: Math.ceil(total / q.limit),
    },
  };
}
import { ApiError } from './http';
